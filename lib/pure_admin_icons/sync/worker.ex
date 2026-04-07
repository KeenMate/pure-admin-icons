defmodule PureAdminIcons.Sync.Worker do
  @moduledoc """
  Worker module that syncs icons from various sources using adapters.

  Supports multiple icon sets: FluentUI, Lucide, Tabler, Heroicons, etc.
  Each icon set has its own adapter that handles downloading and parsing.

  Uses PostgreSQL stage tables for data import:
  1. Insert raw data into stage.icon (and optionally stage.icon_word for synonyms)
  2. Call stage.process_icon_import() which orchestrates:
     - stage._process_icons() - Creates/updates/deletes icons
     - stage._link_primary_name_words() - Links original_name as primary word
     - stage._process_icon_words() - Processes additional synonyms
     - Cleanup of stage data
  """

  require Logger
  alias PureAdminIcons.Repo
  alias PureAdminIcons.Icons
  alias PureAdminIcons.Sync.Adapter
  alias Database.DbContext

  @doc """
  Sync all enabled icon sets.

  Downloads, parses, and stores icons from all registered adapters.
  """
  def sync_all(opts \\ []) do
    icon_sets = Keyword.get(opts, :icon_sets, Adapter.available_icon_sets())

    Logger.info("Starting sync for icon sets: #{Enum.join(icon_sets, ", ")}")

    results =
      Enum.map(icon_sets, fn icon_set ->
        case sync_icon_set(icon_set) do
          {:ok, stats} -> {icon_set, :ok, stats}
          {:error, reason} -> {icon_set, :error, reason}
        end
      end)

    successes = Enum.filter(results, fn {_, status, _} -> status == :ok end)
    failures = Enum.filter(results, fn {_, status, _} -> status == :error end)

    Logger.info("Sync complete: #{length(successes)} succeeded, #{length(failures)} failed")

    if failures == [] do
      {:ok, results}
    else
      {:partial, results}
    end
  end

  @doc """
  Sync a specific icon set using its adapter.
  """
  def sync_icon_set(icon_set) when is_binary(icon_set) do
    case Adapter.get_adapter(icon_set) do
      nil ->
        Logger.error("Unknown icon set: #{icon_set}")
        {:error, "Unknown icon set: #{icon_set}"}

      adapter ->
        do_sync_icon_set(adapter)
    end
  end

  defp do_sync_icon_set(adapter) do
    icon_set = adapter.icon_set_id()
    Logger.info("[#{icon_set}] Starting sync...")

    # Create job run record
    {:ok, job_run_id} = Icons.create_job_run("sync_worker", "sync_icons", %{icon_set_code: icon_set})

    try do
      with {:ok, extracted_path} <- adapter.download(),
           {:ok, %{icons: icons, synonyms: synonyms, discrepancies: discrepancies}} <- adapter.parse(extracted_path),
           {:ok, svg_count} <- move_svgs_if_configured(adapter, extracted_path) do

        # Insert icons to stage table
        insert_icons_to_stage(icons, icon_set, job_run_id)

        # Insert synonyms to stage table (if any)
        insert_synonyms_to_stage(synonyms, icon_set, job_run_id)

        # Call the unified import function that handles everything
        Logger.info("[#{icon_set}] Stage insert complete, calling process_icon_import...")
        import_stats = process_icon_import(icon_set, job_run_id)
        Logger.info("[#{icon_set}] Import complete: #{inspect(import_stats)}")

        # Cleanup extracted files
        adapter.cleanup(extracted_path)

        # Log discrepancies
        if length(discrepancies) > 0 do
          Logger.warning("[#{icon_set}] Found #{length(discrepancies)} discrepancies")
        end

        # Complete job run
        Logger.info("[#{icon_set}] Storing #{length(discrepancies)} discrepancies in job run")
        Icons.update_job_run(job_run_id, "completed", %{
          icons_created: import_stats.icons_created,
          icons_updated: import_stats.icons_updated,
          icons_deleted: import_stats.icons_deleted,
          icons_unchanged: import_stats.icons_unchanged,
          phrases_created: import_stats.phrases_created,
          phrase_links_created: import_stats.phrase_links_created,
          primary_phrases_linked: import_stats.primary_phrases_linked,
          svgs_downloaded: svg_count,
          discrepancy_count: length(discrepancies),
          discrepancies: discrepancies
        })

        Logger.info("[#{icon_set}] Sync complete!")

        {:ok, %{
          icon_set: icon_set,
          icons_created: import_stats.icons_created,
          icons_updated: import_stats.icons_updated,
          svgs: svg_count,
          phrases_created: import_stats.phrases_created,
          discrepancies: length(discrepancies)
        }}
      else
        {:error, reason} ->
          Logger.error("[#{icon_set}] Sync failed: #{inspect(reason)}")
          Icons.update_job_run(job_run_id, "failed", nil, %{error: inspect(reason)})
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("[#{icon_set}] Sync crashed: #{Exception.message(e)}")
        Logger.error(Exception.format_stacktrace(__STACKTRACE__))
        Icons.update_job_run(job_run_id, "failed", nil, %{error: Exception.message(e)})
        {:error, e}
    end
  end

  defp move_svgs_if_configured(adapter, extracted_path) do
    case Application.get_env(:pure_admin_icons, :icons_path) do
      nil ->
        Logger.info("[#{adapter.icon_set_id()}] No icons_path configured, skipping SVG storage")
        {:ok, 0}

      output_dir ->
        adapter.move_svgs(extracted_path, output_dir)
    end
  end

  # ---- Stage Table Insert Functions ----

  @copy_delimiter "\t"

  defp insert_icons_to_stage(icons, icon_set, job_run_id) do
    Logger.info("[#{icon_set}] Inserting #{length(icons)} icons to stage table...")

    # Clear stage table for this job run (in case of retry)
    Repo.query!("DELETE FROM stage.icon WHERE job_run_id = $1", [job_run_id])

    # Use PostgreSQL COPY for fast bulk loading
    columns = ~w(job_run_id icon_set_code original_name style_code sizes filenames ios_identifiers android_identifiers hash)

    sql = """
    COPY stage.icon(#{Enum.join(columns, ", ")})
    FROM STDIN
    WITH (FORMAT text, NULL 'null', DELIMITER '#{@copy_delimiter}')
    """

    Repo.transaction(fn ->
      stream = Ecto.Adapters.SQL.stream(Repo, sql, [], log: false)

      icons
      |> Stream.map(fn icon -> icon_to_copy_row(icon, icon_set, job_run_id) end)
      |> Enum.into(stream)
    end)

    Logger.debug("[#{icon_set}] COPY complete for #{length(icons)} icons")
  end

  defp icon_to_copy_row(icon, icon_set, job_run_id) do
    hash = compute_icon_hash(icon)

    [
      to_string(job_run_id),
      icon_set,
      icon[:name],
      icon[:style],
      encode_pg_array(icon[:sizes] || []),
      Jason.encode!(icon[:filenames] || %{}),
      Jason.encode!(icon[:ios_identifiers] || %{}),
      Jason.encode!(icon[:android_identifiers] || %{}),
      hash
    ]
    |> Enum.join(@copy_delimiter)
    |> Kernel.<>("\n")
  end

  defp insert_synonyms_to_stage(synonyms, _icon_set, _job_run_id) when map_size(synonyms) == 0 do
    # No synonyms to insert
    :ok
  end

  defp insert_synonyms_to_stage(synonyms, icon_set, job_run_id) do
    # Get styles for this icon set
    adapter = Adapter.get_adapter(icon_set)
    styles = if adapter, do: adapter.styles(), else: ["regular"]

    # Clear stage table for this job run
    Repo.query!("DELETE FROM stage.icon_phrase WHERE job_run_id = $1", [job_run_id])

    # Build phrase entries - expand synonyms across all styles
    # Note: The stage.icon_phrase table uses: icon_original_name, phrase
    stage_phrases =
      synonyms
      |> Enum.flat_map(fn {icon_name, synonym_list} ->
        Enum.flat_map(styles, fn style ->
          Enum.map(synonym_list, fn synonym ->
            %{
              job_run_id: job_run_id,
              icon_set_code: icon_set,
              icon_original_name: icon_name,
              icon_style_code: style,
              phrase: synonym,
              source_code: "metadata"
            }
          end)
        end)
      end)
      |> Enum.uniq_by(fn e -> {e.icon_set_code, e.icon_original_name, e.icon_style_code, e.phrase} end)

    if length(stage_phrases) > 0 do
      Logger.info("[#{icon_set}] Inserting #{length(stage_phrases)} synonym phrases to stage table...")
      copy_phrases_to_stage(stage_phrases, icon_set)
    end

    :ok
  end

  defp copy_phrases_to_stage(phrases, icon_set) do
    # Column names match stage.icon_phrase schema
    columns = ~w(job_run_id icon_set_code icon_original_name icon_style_code phrase source_code)

    sql = """
    COPY stage.icon_phrase(#{Enum.join(columns, ", ")})
    FROM STDIN
    WITH (FORMAT text, NULL 'null', DELIMITER '#{@copy_delimiter}')
    """

    Repo.transaction(fn ->
      stream = Ecto.Adapters.SQL.stream(Repo, sql, [], log: false)

      phrases
      |> Stream.map(fn p -> phrase_to_copy_row(p) end)
      |> Enum.into(stream)
    end)

    Logger.debug("[#{icon_set}] COPY complete for #{length(phrases)} phrases")
  end

  defp phrase_to_copy_row(phrase) do
    [
      to_string(phrase.job_run_id),
      escape_copy_field(phrase.icon_set_code),
      escape_copy_field(phrase.icon_original_name),
      escape_copy_field(phrase.icon_style_code),
      escape_copy_field(phrase.phrase),
      escape_copy_field(phrase.source_code)
    ]
    |> Enum.join(@copy_delimiter)
    |> Kernel.<>("\n")
  end

  # Escape special characters for PostgreSQL COPY TEXT format
  defp escape_copy_field(nil), do: "\\N"
  defp escape_copy_field(value) when is_binary(value) do
    value
    |> String.replace("\\", "\\\\")  # Escape backslashes first
    |> String.replace("\t", "\\t")   # Escape tabs
    |> String.replace("\n", "\\n")   # Escape newlines
    |> String.replace("\r", "\\r")   # Escape carriage returns
  end
  defp escape_copy_field(value), do: to_string(value)

  # ---- Import Processing ----

  defp process_icon_import(icon_set, job_run_id) do
    # Call the unified import function with extended timeout (5 minutes)
    case DbContext.stage_process_icon_import("sync_worker", job_run_id, timeout: 300_000) do
      {:ok, [stats]} ->
        %{
          icons_created: stats.icons_created,
          icons_updated: stats.icons_updated,
          icons_deleted: stats.icons_deleted,
          icons_unchanged: stats.icons_unchanged,
          phrases_created: stats.phrases_created,
          phrase_links_created: stats.phrase_links_created,
          phrase_links_deleted: stats.phrase_links_deleted,
          primary_phrases_linked: stats.primary_phrases_linked
        }

      {:ok, []} ->
        Logger.warning("[#{icon_set}] process_icon_import returned empty result")
        empty_import_stats()

      {:error, error} ->
        Logger.error("[#{icon_set}] Failed to process import: #{inspect(error)}")
        empty_import_stats()
    end
  end

  defp empty_import_stats do
    %{
      icons_created: 0,
      icons_updated: 0,
      icons_deleted: 0,
      icons_unchanged: 0,
      phrases_created: 0,
      phrase_links_created: 0,
      phrase_links_deleted: 0,
      primary_phrases_linked: 0
    }
  end

  # ---- Helpers ----

  defp encode_pg_array([]), do: "{}"
  defp encode_pg_array(list) when is_list(list) do
    "{" <> Enum.join(list, ",") <> "}"
  end

  defp compute_icon_hash(icon) do
    data = %{
      sizes: icon[:sizes] || [],
      filenames: icon[:filenames] || %{},
      ios: icon[:ios_identifiers] || %{},
      android: icon[:android_identifiers] || %{}
    }

    :crypto.hash(:md5, Jason.encode!(data))
    |> Base.encode16(case: :lower)
  end

  # Legacy function for backwards compatibility
  @doc """
  Sync FluentUI icons (legacy function).
  Use sync_icon_set("fluentui") instead.
  """
  def sync_fluentui(_opts \\ []) do
    sync_icon_set("fluentui")
  end
end

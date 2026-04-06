defmodule PureAdminIcons.Synonyms.Seeder do
  @moduledoc """
  Seeds icon synonyms from priv/synonyms.json into the database.

  This runs on application startup to ensure synonyms are always in sync
  with the JSON file committed to git.

  Note: The synonyms.json file contains FluentUI-specific synonyms only.
  Other icon sets manage their own synonyms through their adapters.
  """

  require Logger
  alias PureAdminIcons.Repo
  alias PureAdminIcons.Icons.IconSynonym
  import Ecto.Query

  @icon_set "fluentui"
  @styles ~w(regular filled color light)

  @doc """
  Seed synonyms from JSON file into the database.

  Only seeds if FluentUI synonyms are missing (first run).
  Use `seed!(force: true)` to force re-seeding.
  Does nothing if the file doesn't exist.
  """
  def seed(opts \\ []) do
    force = Keyword.get(opts, :force, false)

    if not force and has_synonyms?() do
      Logger.debug("FluentUI synonyms already exist, skipping seeding")
      :ok
    else
      do_seed()
    end
  end

  @doc """
  Check if FluentUI synonyms exist in the database.
  """
  def has_synonyms? do
    Repo.exists?(from(s in IconSynonym, where: s.icon_set == ^@icon_set))
  end

  defp do_seed do
    case File.read(synonyms_file()) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, synonyms_map} ->
            sync_synonyms(synonyms_map)
            Logger.info("Seeded #{map_size(synonyms_map)} FluentUI icon synonym mappings")
            :ok

          {:error, reason} ->
            Logger.error("Failed to parse synonyms.json: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, :enoent} ->
        Logger.debug("No synonyms.json file found, skipping synonym seeding")
        :ok

      {:error, reason} ->
        Logger.error("Failed to read synonyms.json: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp sync_synonyms(synonyms_map) do
    Repo.transaction(fn ->
      # Clear existing FluentUI synonyms only (preserve other icon sets)
      Repo.delete_all(from(s in IconSynonym, where: s.icon_set == ^@icon_set))

      # Build entries - all values lowercased at insert time
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      entries =
        for {icon_name, syns} <- synonyms_map,
            style <- @styles,
            synonym <- syns do
          %{
            icon_set: @icon_set,
            icon_name_lower: String.downcase(icon_name),
            icon_style: style,
            synonym: String.downcase(synonym),
            inserted_at: now,
            updated_at: now
          }
        end

      # Bulk insert
      if entries != [] do
        Repo.insert_all(IconSynonym, entries, on_conflict: :nothing)
      end
    end)
  end

  # Get the correct path to synonyms.json in any environment (dev or release)
  defp synonyms_file do
    :pure_admin_icons
    |> :code.priv_dir()
    |> Path.join("synonyms.json")
  end
end

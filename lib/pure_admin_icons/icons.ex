defmodule PureAdminIcons.Icons do
  @moduledoc """
  The Icons context - handles searching and querying icons from multiple icon sets.
  Uses PostgreSQL stored functions via Database.DbContext.
  """

  alias PureAdminIcons.Repo
  alias Database.DbContext

  def search(query, opts \\ []) do
    criteria = build_search_criteria(query, opts)
    page = opts[:page] || 1
    page_size = opts[:limit] || 50
    criteria_json = Jason.encode!(criteria)
    case DbContext.search_icons(criteria_json, page, page_size) do
      {:ok, results} -> {:ok, results}
      {:error, _} = error -> error
    end
  end

  def search!(query, opts \\ []) do
    case search(query, opts) do
      {:ok, results} -> results
      {:error, error} -> raise "Search failed: #{inspect(error)}"
    end
  end

  defp build_search_criteria(query, opts) do
    criteria = %{}
    criteria = if query && query != "", do: Map.put(criteria, "search_text", query), else: criteria
    criteria = case opts[:icon_sets] do
      nil -> criteria
      [] -> criteria
      sets when is_list(sets) -> Map.put(criteria, "icon_sets", sets)
    end
    criteria = case opts[:styles] do
      nil -> criteria
      [] -> criteria
      styles when is_list(styles) -> Map.put(criteria, "styles", styles)
    end
    criteria = case opts[:sizes] do
      nil -> criteria
      [] -> criteria
      sizes when is_list(sizes) ->
        # Special: size 0 means "scalable icons only"
        if 0 in sizes do
          criteria = Map.put(criteria, "has_single_source", true)
          # If there are also pixel sizes, include them too
          pixel_sizes = Enum.reject(sizes, &(&1 == 0))
          case pixel_sizes do
            [] -> criteria
            [size | _] -> Map.put(criteria, "size", size)
          end
        else
          [size | _] = sizes
          Map.put(criteria, "size", size)
        end
    end
    criteria = case opts[:categories] do
      nil -> criteria
      [] -> criteria
      cats when is_list(cats) -> Map.put(criteria, "categories", cats)
    end
    criteria
  end

  def search_count(query, opts \\ []) do
    case search(query, Keyword.put(opts, :limit, 1)) do
      {:ok, [first | _]} -> first.total_items
      {:ok, []} -> 0
      {:error, _} -> 0
    end
  end

  def count(opts \\ []) do
    icon_set = opts[:icon_set]
    case DbContext.get_icon_count(icon_set || :eg_value_not_provided) do
      {:ok, [%{get_icon_count: count}]} -> count
      {:ok, []} -> 0
      {:error, _} -> 0
    end
  end

  def counts_by_icon_set do
    case DbContext.get_icon_counts_by_set() do
      {:ok, results} ->
        results |> Enum.map(fn %{icon_set_code: code, count: count} -> {code, count} end) |> Map.new()
      {:error, _} -> %{}
    end
  end

  def list_icon_sets(locale \\ nil) do
    lang = locale || PureAdminIcons.Translations.Locale.get()

    case DbContext.const_get_icon_sets(lang) do
      {:ok, results} -> results
      {:error, _} -> []
    end
  end

  def get_icon!(id) do
    case DbContext.get_icon_detail(id) do
      {:ok, [icon]} -> icon
      {:ok, []} -> raise "Icon not found: #{id}"
      {:error, error} -> raise "Failed to get icon: #{inspect(error)}"
    end
  end

  def get_icon(id) do
    case DbContext.get_icon_detail(id) do
      {:ok, [icon]} -> {:ok, icon}
      {:ok, []} -> {:error, :not_found}
      {:error, _} = error -> error
    end
  end

  def track_action(icon_id, action, source, opts \\ []) do
    # Pass nil (not :eg_value_not_provided) so positional params stay aligned —
    # the DB SP treats NULL as "no value" and the sentinel would get filtered
    # out, shifting `platform` into the size slot.
    size = opts[:size]
    platform = opts[:platform]
    case DbContext.track_icon_action(icon_id, action, source, size, platform) do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  def icon_metrics(icon_id) do
    case DbContext.get_icon_metrics(icon_id) do
      {:ok, results} ->
        results |> Enum.map(fn %{action_code: action, period_code: period, count: count} -> {{action, period}, count} end) |> Map.new()
      {:error, _} -> %{}
    end
  end

  def refresh_metrics_cube do
    require Logger
    Logger.info("Refreshing metrics cube...")
    case DbContext.refresh_icon_metrics_cube() do
      {:ok, _} -> Logger.info("Metrics cube refresh complete"); :ok
      {:error, error} -> Logger.error("Metrics cube refresh failed: #{inspect(error)}"); {:error, error}
    end
  end

  def stats_overview do
    case DbContext.get_stats_overview() do
      {:ok, results} -> {:ok, results}
      {:error, _} = error -> error
    end
  end

  def popular_icons_from_cube(opts \\ []) do
    period = opts[:period] || "30d"
    action = opts[:action] || "copy"
    limit = opts[:limit] || 20
    # Pass nil (not :eg_value_not_provided) so positional params stay aligned —
    # the DB function treats NULL as "no filter" for optional params
    icon_set = opts[:icon_set]
    style = opts[:style]
    source = opts[:source]

    Repo.query(
      "select * from public.get_popular_icons($1, $2, $3, $4, $5, $6)",
      [period, action, icon_set, style, source, limit]
    )
    |> Database.Processors.GetPopularIconsProcessor.parse_result()
  end

  def get_last_sync(icon_set_code \\ nil) do
    case DbContext.get_last_sync(icon_set_code || :eg_value_not_provided) do
      {:ok, [sync]} -> {:ok, sync}
      {:ok, []} -> {:ok, nil}
      {:ok, syncs} when is_list(syncs) -> {:ok, syncs}
      {:error, _} = error -> error
    end
  end

  def create_job_run(run_by, job_type, job_data \\ nil) do
    case DbContext.create_job_run(run_by, job_type, job_data || :eg_value_not_provided) do
      {:ok, [%{create_job_run: job_run_id}]} -> {:ok, job_run_id}
      {:error, _} = error -> error
    end
  end

  def update_job_run(job_run_id, status, success_data \\ nil, fail_data \\ nil) do
    Repo.query("SELECT public.update_job_run($1, $2, $3, $4)", [job_run_id, status, success_data, fail_data])
  end
end

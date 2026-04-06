defmodule Mix.Tasks.Icons.Download do
  @moduledoc """
  Performs a full sync of icons from one or more icon sets.

  ## Usage

      # Sync all icon sets (fluentui, lucide, tabler, heroicons)
      mix icons.download

      # Sync specific icon set(s)
      mix icons.download fluentui
      mix icons.download lucide tabler
      mix icons.download --set=heroicons --set=lucide

      # Force fresh download (skip cache)
      mix icons.download fluentui --fresh
      mix icons.download --fresh          # All sets, skip cache

      # Clear cache for specific set
      mix icons.download --clear-cache=fluentui

      # Clear all caches
      mix icons.download --clear-cache

  ## Available Icon Sets

  - `fluentui` - Microsoft FluentUI System Icons (6,000+ icons)
  - `lucide` - Lucide Icons (1,500+ icons)
  - `tabler` - Tabler Icons (5,800+ icons)
  - `heroicons` - Heroicons by Tailwind Labs (450+ icons)

  Icons are downloaded to the path configured via `config :pure_admin_icons, icons_path: "..."`.
  In dev, this defaults to `.icons/` in the project root.
  In prod, set the ICONS_PATH environment variable.

  ## Development Caching

  In dev mode (`config :pure_admin_icons, use_icon_cache: true`), extracted icon repos are
  cached in `.cache/icons/` to avoid re-downloading during iterative development.
  Use `--fresh` to bypass the cache, or `--clear-cache` to clear it.
  """
  use Mix.Task

  alias PureAdminIcons.Sync.Adapter

  @shortdoc "Sync icons from icon sets (DB + files)"

  @switches [set: :keep, fresh: :boolean, clear_cache: :string]

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} = OptionParser.parse(args, switches: @switches)

    Mix.Task.run("app.start")

    # Handle --clear-cache flag
    case Keyword.get(opts, :clear_cache) do
      nil -> :ok
      "true" ->
        Mix.shell().info("Clearing all icon caches...")
        Adapter.clear_cache()
        Mix.shell().info("Cache cleared!")
        # If only clearing cache, exit early
        if positional == [] and not Keyword.get(opts, :fresh, false) do
          return_early()
        end
      icon_set when is_binary(icon_set) ->
        Mix.shell().info("Clearing cache for #{icon_set}...")
        Adapter.clear_cache(icon_set)
        Mix.shell().info("Cache cleared!")
    end

    # Handle --fresh flag - clear caches before sync
    if Keyword.get(opts, :fresh, false) do
      sets_from_opts = Keyword.get_values(opts, :set)
      icon_sets = (sets_from_opts ++ positional) |> Enum.uniq()

      if icon_sets == [] do
        Mix.shell().info("Fresh sync requested, clearing all caches...")
        Adapter.clear_cache()
      else
        Enum.each(icon_sets, fn set ->
          Mix.shell().info("Fresh sync requested, clearing cache for #{set}...")
          Adapter.clear_cache(set)
        end)
      end
    end

    # Collect icon sets from both --set=X flags and positional args
    sets_from_opts = Keyword.get_values(opts, :set)
    icon_sets = (sets_from_opts ++ positional) |> Enum.uniq()

    case icon_sets do
      [] ->
        Mix.shell().info("Starting full sync of all icon sets...")
        PureAdminIcons.Sync.Worker.sync_all()

      sets ->
        Mix.shell().info("Syncing icon sets: #{Enum.join(sets, ", ")}...")
        for set <- sets do
          Mix.shell().info("\n=== Syncing #{set} ===")
          case PureAdminIcons.Sync.Worker.sync_icon_set(set) do
            {:ok, _} -> Mix.shell().info("#{set}: OK")
            {:error, reason} -> Mix.shell().error("#{set}: FAILED - #{inspect(reason)}")
          end
        end
    end

    Mix.shell().info("\nDone!")
  end

  defp return_early do
    throw(:early_return)
  catch
    :early_return -> :ok
  end
end

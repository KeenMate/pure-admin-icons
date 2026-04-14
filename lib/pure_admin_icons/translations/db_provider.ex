defmodule PureAdminIcons.Translations.DbProvider do
  @moduledoc """
  DB-backed translation provider for `PureAdminIcons.Translations`.

  Wires up via config:

      config :pure_admin_icons,
        translate: &PureAdminIcons.Translations.DbProvider.translate/2

  Reads from `public.get_group_translations(lang, 'frontend', 'text', 1)` which
  returns a single-row result with one JSONB column: `%{"code" => "value", ...}`.

  Per-locale maps are cached in `:persistent_term`. Call `refresh/0` to drop
  the cache after a write (or `refresh/1` for a specific locale).

  Returns `nil` when:
    - the locale's DB map doesn't contain the key
    - the DB call fails

  `nil` triggers fallback to `@defaults` inside `PureAdminIcons.Translations.t/2`.
  """

  require Logger

  alias Database.DbContext
  alias PureAdminIcons.Translations
  alias PureAdminIcons.Translations.Locale

  @cache_key {__MODULE__, :by_locale}

  @data_group "frontend"
  @context "text"
  @tenant_id 1

  @doc """
  Translation callback. Called by `PureAdminIcons.Translations.t/2`.

  Returns the translated + interpolated string, or `nil` to fall back to defaults.
  """
  def translate(key, params) when is_binary(key) and is_map(params) do
    case locale_map(Locale.get()) do
      %{} = map ->
        case Map.get(map, key) do
          nil -> nil
          value -> Translations.interpolate(value, params)
        end

      _ ->
        nil
    end
  end

  @doc "Drop the cache for all locales (or a specific one). Call after writes."
  def refresh(locale \\ :all) do
    all = :persistent_term.get(@cache_key, %{})

    new =
      case locale do
        :all -> %{}
        l when is_binary(l) -> Map.delete(all, l)
      end

    :persistent_term.put(@cache_key, new)
    :ok
  end

  # --- internals ---

  defp locale_map(locale) do
    case :persistent_term.get(@cache_key, %{}) do
      %{^locale => map} ->
        map

      cache ->
        case fetch(locale) do
          {:ok, map} ->
            :persistent_term.put(@cache_key, Map.put(cache, locale, map))
            map

          :error ->
            # Cache the miss as an empty map so we don't hammer the DB on every call.
            :persistent_term.put(@cache_key, Map.put(cache, locale, %{}))
            %{}
        end
    end
  end

  defp fetch(locale) do
    case DbContext.get_group_translations(locale, @data_group, @context, @tenant_id) do
      {:ok, [%{get_group_translations: map}]} when is_map(map) ->
        {:ok, map}

      {:ok, []} ->
        {:ok, %{}}

      {:error, reason} ->
        Logger.warning("[Translations.DbProvider] fetch failed for #{locale}: #{inspect(reason)}")
        :error

      other ->
        Logger.warning("[Translations.DbProvider] unexpected result for #{locale}: #{inspect(other)}")
        :error
    end
  end
end

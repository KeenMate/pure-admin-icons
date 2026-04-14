defmodule PureAdminIconsWeb.Plugs.Locale do
  @moduledoc """
  Resolves the current request's locale and stores it via `PureAdminIcons.Translations.Locale.put/1`.

  Resolution order (first match wins):

    1. `?lang=xx` query param (explicit opt-in)
    2. `Accept-Language` header's first acceptable tag
    3. default from config (`en`)

  Only language tags matching the configured whitelist are accepted;
  everything else falls back to the default. Whitelist defaults to
  `["en"]` — extend via:

      config :pure_admin_icons, :supported_locales, ["en", "cs"]

  Plug usage — add to the `:browser` pipeline in the router:

      plug PureAdminIconsWeb.Plugs.Locale

  LiveView usage — attach to routes via `live_session`:

      live_session :default, on_mount: {PureAdminIconsWeb.Plugs.Locale, :default} do
        live "/", IconSearchLive
        # …
      end
  """

  alias PureAdminIcons.Translations.Locale

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    locale = resolve(conn)
    Locale.put(locale)

    conn
    |> Plug.Conn.put_session(:locale, locale)
    |> Plug.Conn.assign(:locale, locale)
  end

  @doc """
  LiveView `on_mount` hook. Reads the locale stashed in the session by the
  plug (or falls back to default) and sets it on the LiveView process.
  """
  def on_mount(:default, _params, session, socket) do
    locale = session["locale"] || Locale.default()
    Locale.put(locale)
    {:cont, Phoenix.Component.assign(socket, :locale, locale)}
  end

  # --- resolution ---

  defp resolve(conn) do
    supported = supported_locales()
    default = Locale.default()

    # Query param wins (explicit switch), then session cookie (sticky choice),
    # then Accept-Language header, then default.
    pick(from_query(conn), supported) ||
      pick(from_session(conn), supported) ||
      pick(from_header(conn), supported) ||
      default
  end

  defp from_session(conn) do
    case Plug.Conn.get_session(conn, :locale) do
      lang when is_binary(lang) and lang != "" -> lang
      _ -> nil
    end
  end

  defp pick(nil, _), do: nil
  defp pick(locale, supported) do
    if locale in supported, do: locale, else: nil
  end

  defp from_query(conn) do
    case Plug.Conn.fetch_query_params(conn).query_params do
      %{"lang" => lang} when is_binary(lang) and lang != "" -> normalize(lang)
      _ -> nil
    end
  end

  defp from_header(conn) do
    case Plug.Conn.get_req_header(conn, "accept-language") do
      [header | _] ->
        header
        |> String.split(",", trim: true)
        |> Enum.map(&parse_language_tag/1)
        |> Enum.reject(&is_nil/1)
        |> List.first()

      _ ->
        nil
    end
  end

  # Accept-Language tags look like "en-US;q=0.9". Strip q-value, take primary subtag.
  defp parse_language_tag(tag) do
    tag
    |> String.split(";", parts: 2)
    |> List.first()
    |> String.trim()
    |> case do
      "" -> nil
      t -> normalize(t)
    end
  end

  defp normalize(lang) do
    lang
    |> String.downcase()
    |> String.split("-", parts: 2)
    |> List.first()
  end

  defp supported_locales do
    Application.get_env(:pure_admin_icons, :supported_locales, ["en"])
  end
end

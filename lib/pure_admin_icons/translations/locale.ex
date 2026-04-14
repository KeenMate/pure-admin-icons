defmodule PureAdminIcons.Translations.Locale do
  @moduledoc """
  Current locale resolution for translations.

  The locale is stored in the process dictionary so it's available to any
  `PureAdminIcons.Translations.t/1` call in the same process — whether that's
  a Plug-handled request, a LiveView process, a Task, or an IEx session.

  Set per request via `PureAdminIconsWeb.Plugs.Locale` plug and mirrored onto
  the LiveView socket via the `on_mount` hook of the same module.
  """

  @process_key :pure_admin_icons_locale

  @default_locale "en"

  @doc "Returns the current locale, falling back to the configured default."
  def get do
    Process.get(@process_key) || default()
  end

  @doc "Sets the locale for the current process."
  def put(locale) when is_binary(locale) and locale != "" do
    Process.put(@process_key, locale)
    locale
  end

  @doc "Returns the configured default locale (`en` unless overridden)."
  def default do
    Application.get_env(:pure_admin_icons, :default_locale, @default_locale)
  end
end

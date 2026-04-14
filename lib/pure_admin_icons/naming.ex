defmodule PureAdminIcons.Naming do
  @moduledoc """
  Case / separator transforms for icon identifiers.

  All functions accept input with any combination of spaces, hyphens, and
  underscores as word separators — the split is `[-_\\s]+`. Handy for
  converting between human-readable names (`"Admin Panel Settings"`) and
  the various casings platform SDKs expect.

      iex> Naming.snake_case("Admin Panel Settings")
      "admin_panel_settings"

      iex> Naming.kebab_case("Admin_Panel_Settings")
      "admin-panel-settings"

      iex> Naming.pascal_case("admin-panel-settings")
      "AdminPanelSettings"

      iex> Naming.camel_case("admin panel settings")
      "adminPanelSettings"

      iex> Naming.title_case("admin-panel-settings")
      "Admin Panel Settings"
  """

  @separators ~r/[-_\s]+/

  @doc "Lowercase words joined with `_`."
  def snake_case(name), do: name |> words() |> Enum.map(&String.downcase/1) |> Enum.join("_")

  @doc "Lowercase words joined with `-`."
  def kebab_case(name), do: name |> words() |> Enum.map(&String.downcase/1) |> Enum.join("-")

  @doc "Each word capitalized, no separators: `AdminPanelSettings`."
  def pascal_case(name), do: name |> words() |> Enum.map(&capitalize/1) |> Enum.join()

  @doc "First word lowercase, rest capitalized: `adminPanelSettings`."
  def camel_case(name) do
    name
    |> words()
    |> Enum.with_index()
    |> Enum.map(fn
      {w, 0} -> String.downcase(w)
      {w, _} -> capitalize(w)
    end)
    |> Enum.join()
  end

  @doc "Words capitalized, joined with spaces: `Admin Panel Settings`."
  def title_case(name), do: name |> words() |> Enum.map(&capitalize/1) |> Enum.join(" ")

  @doc """
  Splits a name on any `_`, `-`, or whitespace into non-empty words.

      iex> Naming.words("Admin Panel Settings")
      ["Admin", "Panel", "Settings"]
  """
  def words(name) when is_binary(name), do: String.split(name, @separators, trim: true)

  # Safer than String.capitalize/1 on acronyms — only touches the first char.
  defp capitalize(""), do: ""
  defp capitalize(<<first::utf8, rest::binary>>) do
    <<String.upcase(<<first::utf8>>)::binary, String.downcase(rest)::binary>>
  end
end

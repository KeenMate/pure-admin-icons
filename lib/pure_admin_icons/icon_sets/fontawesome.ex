defmodule PureAdminIcons.IconSets.Fontawesome do
  @moduledoc """
  Identifier and package formatting for Font Awesome Free.

  - React: `@fortawesome/react-fontawesome` (FontAwesomeIcon + style-specific icon import)
  - Vue: `@fortawesome/vue-fontawesome`
  - Svelte: `svelte-fa` (community)
  - CSS class: `@fortawesome/fontawesome-free` web font (`<i class="fa-solid fa-name"></i>`)
  """
  @behaviour PureAdminIcons.IconSets.Formatter

  @impl true
  def react_identifier(icon, _size) do
    fa_name = to_fa_import_name(icon.name)
    pkg = style_package(icon.style_code)
    "import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'\n" <>
      "import { #{fa_name} } from '#{pkg}'\n" <>
      "<FontAwesomeIcon icon={#{fa_name}} />"
  end

  @impl true
  def vue_identifier(icon, _size) do
    fa_name = to_fa_import_name(icon.name)
    pkg = style_package(icon.style_code)
    "import { FontAwesomeIcon } from '@fortawesome/vue-fontawesome'\n" <>
      "import { #{fa_name} } from '#{pkg}'\n" <>
      ~s(<font-awesome-icon :icon="#{fa_name}" />)
  end

  @impl true
  def svelte_identifier(icon, _size) do
    fa_name = to_fa_import_name(icon.name)
    pkg = style_package(icon.style_code)
    "import Fa from 'svelte-fa'\n" <>
      "import { #{fa_name} } from '#{pkg}'\n" <>
      "<Fa icon={#{fa_name}} />"
  end

  @impl true
  def cssclass_identifier(icon, _size) do
    kebab = icon.name |> String.downcase() |> String.replace(" ", "-")
    style_prefix =
      case icon.style_code do
        "solid" -> "fa-solid"
        "regular" -> "fa-regular"
        "brands" -> "fa-brands"
        _ -> "fa-solid"
      end
    "#{style_prefix} fa-#{kebab}"
  end

  @impl true
  def react_package(_), do: {"@fortawesome/react-fontawesome", "https://www.npmjs.com/package/@fortawesome/react-fontawesome"}

  @impl true
  def vue_package(_), do: {"@fortawesome/vue-fontawesome", "https://www.npmjs.com/package/@fortawesome/vue-fontawesome"}

  @impl true
  def svelte_package(_), do: {"svelte-fa", "https://www.npmjs.com/package/svelte-fa"}

  @impl true
  def cssclass_package(_), do: {"@fortawesome/fontawesome-free", "https://www.npmjs.com/package/@fortawesome/fontawesome-free"}

  @impl true
  def react_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]

  @impl true
  def vue_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]

  @impl true
  def svelte_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]

  # Private helpers

  # "Arrow Right" -> "faArrowRight"
  defp to_fa_import_name(display_name) do
    pascal = display_name |> String.replace(" ", "")
    "fa#{pascal}"
  end

  defp style_package("solid"), do: "@fortawesome/free-solid-svg-icons"
  defp style_package("regular"), do: "@fortawesome/free-regular-svg-icons"
  defp style_package("brands"), do: "@fortawesome/free-brands-svg-icons"
  defp style_package(_), do: "@fortawesome/free-solid-svg-icons"
end

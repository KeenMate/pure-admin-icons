defmodule PureAdminIcons.IconSets.Tabler do
  @moduledoc """
  Identifier and package formatting for Tabler Icons.

  - React: `@tabler/icons-react` (`<IconName />`, "Icon" prefix)
  - Vue: `@tabler/icons-vue` (`<IconName />`)
  - Svelte: `@tabler/icons-svelte` (`<IconName />`)
  - CSS class: `@tabler/icons-webfont` (`<i class="ti ti-name"></i>`)
  """
  @behaviour PureAdminIcons.IconSets.Formatter

  @impl true
  def react_identifier(icon, _size) do
    name = icon.name |> String.replace(" ", "")
    "import { Icon#{name} } from '@tabler/icons-react'\n<Icon#{name} />"
  end

  @impl true
  def vue_identifier(icon, _size) do
    name = icon.name |> String.replace(" ", "")
    "import { Icon#{name} } from '@tabler/icons-vue'\n<Icon#{name} />"
  end

  @impl true
  def svelte_identifier(icon, _size) do
    name = icon.name |> String.replace(" ", "")
    "import { Icon#{name} } from '@tabler/icons-svelte'\n<Icon#{name} />"
  end

  @impl true
  def cssclass_identifier(icon, _size) do
    kebab = icon.name |> String.downcase() |> String.replace(" ", "-")
    suffix = if icon.style_code == "filled", do: "-filled", else: ""
    "ti ti-#{kebab}#{suffix}"
  end

  @impl true
  def react_package(_), do: {"@tabler/icons-react", "https://www.npmjs.com/package/@tabler/icons-react"}

  @impl true
  def vue_package(_), do: {"@tabler/icons-vue", "https://www.npmjs.com/package/@tabler/icons-vue"}

  @impl true
  def svelte_package(_), do: {"@tabler/icons-svelte", "https://tabler.io/icons"}

  @impl true
  def cssclass_package(_), do: {"@tabler/icons-webfont", "https://www.npmjs.com/package/@tabler/icons-webfont"}

  @impl true
  def ios_package(_), do: {nil, nil}

  @impl true
  def android_package(_), do: {nil, nil}

  @impl true
  def react_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]

  @impl true
  def vue_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]

  @impl true
  def svelte_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]
end

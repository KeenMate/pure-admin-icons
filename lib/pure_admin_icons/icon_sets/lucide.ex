defmodule PureAdminIcons.IconSets.Lucide do
  @moduledoc """
  Identifier and package formatting for Lucide Icons.

  - React: `lucide-react` (PascalCase component, no size/style in name)
  - Vue: `lucide-vue-next`
  - Svelte: `lucide-svelte`
  - CSS class: not supported (SVG only)
  """
  @behaviour PureAdminIcons.IconSets.Formatter

  @impl true
  def react_identifier(icon, _size) do
    name = icon.name |> String.replace(" ", "")
    "import { #{name} } from 'lucide-react'\n<#{name} />"
  end

  @impl true
  def vue_identifier(icon, _size) do
    name = icon.name |> String.replace(" ", "")
    "import { #{name} } from 'lucide-vue-next'\n<#{name} />"
  end

  @impl true
  def svelte_identifier(icon, _size) do
    name = icon.name |> String.replace(" ", "")
    "import { #{name} } from 'lucide-svelte'\n<#{name} />"
  end

  @impl true
  def cssclass_identifier(_icon, _size), do: nil

  @impl true
  def react_package(_), do: {"lucide-react", "https://www.npmjs.com/package/lucide-react"}

  @impl true
  def vue_package(_), do: {"lucide-vue-next", "https://www.npmjs.com/package/lucide-vue-next"}

  @impl true
  def svelte_package(_), do: {"lucide-svelte", "https://lucide.dev"}

  @impl true
  def cssclass_package(_), do: {nil, nil}

  @impl true
  def react_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]

  @impl true
  def vue_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]

  @impl true
  def svelte_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]
end

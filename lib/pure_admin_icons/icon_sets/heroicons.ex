defmodule PureAdminIcons.IconSets.Heroicons do
  @moduledoc """
  Identifier and package formatting for Heroicons (Tailwind Labs).

  - React: `@heroicons/react` (`<NameIcon />`, import path varies by size+style)
  - Vue: `@heroicons/vue` (same pattern as React)
  - Svelte: `svelte-hero-icons` (community, uses `<Icon src={Name} />` API)
  - CSS class: not supported (SVG only)
  """
  @behaviour PureAdminIcons.IconSets.Formatter

  @impl true
  def react_identifier(icon, size) do
    name = icon.name |> String.replace(" ", "")
    "import { #{name}Icon } from '@heroicons/react/#{size}/#{icon.style_code}'\n<#{name}Icon />"
  end

  @impl true
  def vue_identifier(icon, size) do
    name = icon.name |> String.replace(" ", "")
    "import { #{name}Icon } from '@heroicons/vue/#{size}/#{icon.style_code}'\n<#{name}Icon />"
  end

  @impl true
  def svelte_identifier(icon, _size) do
    name = icon.name |> String.replace(" ", "")
    variant = if icon.style_code != "outline", do: " #{icon.style_code}", else: ""
    "import { Icon, #{name} } from 'svelte-hero-icons'\n<Icon src={#{name}}#{variant} />"
  end

  @impl true
  def cssclass_identifier(_icon, _size), do: nil

  @impl true
  def react_package(_), do: {"@heroicons/react", "https://www.npmjs.com/package/@heroicons/react"}

  @impl true
  def vue_package(_), do: {"@heroicons/vue", "https://www.npmjs.com/package/@heroicons/vue"}

  @impl true
  def svelte_package(_), do: {"svelte-hero-icons", "https://www.npmjs.com/package/svelte-hero-icons"}

  @impl true
  def cssclass_package(_), do: {nil, nil}

  # Heroicons React/Vue import paths vary by size, so loop over all sizes
  @impl true
  def react_identifier_sizes(icon), do: icon.sizes

  @impl true
  def vue_identifier_sizes(icon), do: icon.sizes

  @impl true
  def svelte_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]
end

defmodule PureAdminIcons.IconSets.Fluentui do
  @moduledoc """
  Identifier and package formatting for Microsoft FluentUI System Icons.

  - React: `@fluentui/react-icons` (PascalCase + size + style: `<ArrowClockwise24Regular />`)
  - Svelte: `svelte-fluentui` (`<Icon name="..." size={..} variant="..." />`)
  - Vue: no official package
  - CSS class: not supported (SVG only)
  """
  @behaviour PureAdminIcons.IconSets.Formatter

  @impl true
  def react_identifier(icon, size) do
    name = icon.name |> String.replace(" ", "")
    style = icon.style_code |> String.capitalize()
    "<#{name}#{size}#{style} />"
  end

  @impl true
  def vue_identifier(_icon, _size), do: nil

  @impl true
  def svelte_identifier(icon, size) do
    name = icon.name |> String.downcase() |> String.replace(" ", "_")
    ~s(<Icon name="#{name}" size={#{size}} variant="#{icon.style_code}" />)
  end

  @impl true
  def cssclass_identifier(_icon, _size), do: nil

  @impl true
  def react_package(_), do: {"@fluentui/react-icons", "https://www.npmjs.com/package/@fluentui/react-icons"}

  @impl true
  def vue_package(_), do: {nil, nil}

  @impl true
  def svelte_package(_), do: {"svelte-fluentui", "https://svelte-fluentui.keenmate.dev"}

  @impl true
  def cssclass_package(_), do: {nil, nil}

  @impl true
  def ios_package(_), do: {"FluentIcons (Swift)", "https://github.com/microsoft/fluentui-system-icons/tree/main/ios"}

  @impl true
  def android_package(_), do: {"fluentui-system-icons (Android)", "https://github.com/microsoft/fluentui-system-icons/tree/main/android"}

  @impl true
  def react_identifier_sizes(icon), do: icon.sizes

  @impl true
  def vue_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]

  @impl true
  def svelte_identifier_sizes(icon), do: icon.sizes
end

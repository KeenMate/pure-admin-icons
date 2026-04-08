defmodule PureAdminIcons.IconSets.Generic do
  @moduledoc """
  Fallback formatter used when an icon's `icon_set_code` doesn't match any registered set.
  Returns minimal placeholder values so the UI degrades gracefully.
  """
  @behaviour PureAdminIcons.IconSets.Formatter

  @impl true
  def react_identifier(icon, size) do
    name = icon.name |> String.replace(" ", "")
    "<#{name}#{size} />"
  end

  @impl true
  def vue_identifier(icon, _size) do
    name = icon.name |> String.replace(" ", "")
    "<#{name} />"
  end

  @impl true
  def svelte_identifier(icon, size) do
    name = icon.name |> String.downcase() |> String.replace(" ", "_")
    ~s(<Icon name="#{name}" size={#{size}} />)
  end

  @impl true
  def cssclass_identifier(_icon, _size), do: nil

  @impl true
  def react_package(_), do: {nil, nil}

  @impl true
  def vue_package(_), do: {nil, nil}

  @impl true
  def svelte_package(_), do: {nil, nil}

  @impl true
  def cssclass_package(_), do: {nil, nil}

  @impl true
  def react_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]

  @impl true
  def vue_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]

  @impl true
  def svelte_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]
end

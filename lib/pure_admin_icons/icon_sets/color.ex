defmodule PureAdminIcons.IconSets.Color do
  @moduledoc """
  Resolves icon-set badge colors from `const.icon_set.brand_color`.
  Caches the code → hex map in `:persistent_term` so badge rendering is hot-path cheap.

  Refresh the cache after a sync (or any time `const.icon_set` changes) by calling `refresh/0`.
  """

  alias PureAdminIcons.Icons

  @cache_key {__MODULE__, :brand_colors}

  @doc """
  Returns an inline `style` attribute string for an icon-set badge,
  or `nil` if no brand color is registered for the code.
  """
  def badge_style(nil), do: nil
  def badge_style(code) when is_binary(code) do
    case Map.get(brand_colors(), code) do
      hex when is_binary(hex) and hex != "" ->
        "background-color: #{hex}; color: #{contrast_text(hex)};"
      _ ->
        nil
    end
  end

  @doc """
  Returns just the `background-color` style for non-text uses (e.g. card
  accent bars). No contrast text color since there's no text.
  """
  def bar_style(nil), do: nil
  def bar_style(code) when is_binary(code) do
    case Map.get(brand_colors(), code) do
      hex when is_binary(hex) and hex != "" -> "background-color: #{hex};"
      _ -> nil
    end
  end

  @doc "Refresh the cache from the DB. Call after a sync."
  def refresh do
    map =
      Icons.list_icon_sets()
      |> Enum.into(%{}, fn s -> {s.code, s.brand_color} end)

    :persistent_term.put(@cache_key, map)
    map
  end

  defp brand_colors do
    case :persistent_term.get(@cache_key, nil) do
      nil -> refresh()
      map -> map
    end
  end

  # Pick black/white text by perceived luminance of the background hex.
  defp contrast_text("#" <> rgb) when byte_size(rgb) == 6 do
    with {r, ""} <- Integer.parse(String.slice(rgb, 0..1), 16),
         {g, ""} <- Integer.parse(String.slice(rgb, 2..3), 16),
         {b, ""} <- Integer.parse(String.slice(rgb, 4..5), 16) do
      if 0.299 * r + 0.587 * g + 0.114 * b > 160, do: "#000", else: "#fff"
    else
      _ -> "#fff"
    end
  end
  defp contrast_text(_), do: "#fff"
end

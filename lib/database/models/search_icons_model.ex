# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Models.SearchIconsModel do
  @moduledoc """
  Model representing the result of public.search_icons
  """

  @fields [
    :rank,
    :similarity,
    :icon_id,
    :icon_set_code,
    :icon_set_title,
    :name,
    :style_code,
    :style_color_method,
    :sizes,
    :filenames,
    :ios_identifiers,
    :android_identifiers,
    :categories,
    :total_items
  ]

  @enforce_keys @fields

  @derive Jason.Encoder
  defstruct @fields

  @type t() :: %__MODULE__{
    rank: float(),
    similarity: float(),
    icon_id: integer(),
    icon_set_code: String.t(),
    icon_set_title: String.t(),
    name: String.t(),
    style_code: String.t(),
    style_color_method: String.t(),
    sizes: list(integer()),
    filenames: map() | list(),
    ios_identifiers: map() | list(),
    android_identifiers: map() | list(),
    categories: map() | list(),
    total_items: integer()
  }

  use Accessible
end

# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Models.SearchIconsModel do
  @moduledoc """
  Model representing the result of public.search_icons
  """

  @fields [
    :rank,
    :similarity,
    :exact_match,
    :synonym_exact_match,
    :icon_id,
    :icon_set_code,
    :icon_set_title,
    :name,
    :style_code,
    :style_color_method,
    :sizes,
    :has_single_source,
    :is_scalable,
    :filenames,
    :platform_identifiers,
    :categories,
    :total_items
  ]

  @enforce_keys @fields

  @derive Jason.Encoder
  defstruct @fields

  @type t() :: %__MODULE__{
    rank: float(),
    similarity: float(),
    exact_match: integer(),
    synonym_exact_match: integer(),
    icon_id: integer(),
    icon_set_code: String.t(),
    icon_set_title: String.t(),
    name: String.t(),
    style_code: String.t(),
    style_color_method: String.t(),
    sizes: list(integer()),
    has_single_source: boolean(),
    is_scalable: boolean(),
    filenames: map() | list(),
    platform_identifiers: map() | list(),
    categories: map() | list(),
    total_items: integer()
  }

  use Accessible
end

# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Models.GetIconDetailModel do
  @moduledoc """
  Model representing the result of public.get_icon_detail
  """

  @fields [
    :icon_id,
    :icon_set_code,
    :icon_set_title,
    :name,
    :style_code,
    :sizes,
    :filenames,
    :ios_identifiers,
    :android_identifiers,
    :categories,
    :phrases
  ]

  @enforce_keys @fields

  @derive Jason.Encoder
  defstruct @fields

  @type t() :: %__MODULE__{
    icon_id: integer(),
    icon_set_code: String.t(),
    icon_set_title: String.t(),
    name: String.t(),
    style_code: String.t(),
    sizes: list(integer()),
    filenames: map() | list(),
    ios_identifiers: map() | list(),
    android_identifiers: map() | list(),
    categories: map() | list(),
    phrases: map() | list()
  }

  use Accessible
end

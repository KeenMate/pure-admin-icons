# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Models.ConstGetIconSetsModel do
  @moduledoc """
  Model representing the result of const.get_icon_sets
  """

  @fields [
    :code,
    :title,
    :license,
    :homepage_url,
    :github_url,
    :styles,
    :sizes,
    :default_size,
    :style_color_methods,
    :icon_count
  ]

  @enforce_keys @fields

  @derive Jason.Encoder
  defstruct @fields

  @type t() :: %__MODULE__{
    code: String.t(),
    title: String.t(),
    license: String.t(),
    homepage_url: String.t(),
    github_url: String.t(),
    styles: list(String.t()),
    sizes: list(integer()),
    default_size: integer(),
    style_color_methods: map() | list(),
    icon_count: integer()
  }

  use Accessible
end

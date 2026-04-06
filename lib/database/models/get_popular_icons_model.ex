# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Models.GetPopularIconsModel do
  @moduledoc """
  Model representing the result of public.get_popular_icons
  """

  @fields [
    :icon_id,
    :icon_set_code,
    :name,
    :style_code,
    :count
  ]

  @enforce_keys @fields

  @derive Jason.Encoder
  defstruct @fields

  @type t() :: %__MODULE__{
    icon_id: integer(),
    icon_set_code: String.t(),
    name: String.t(),
    style_code: String.t(),
    count: integer()
  }

  use Accessible
end

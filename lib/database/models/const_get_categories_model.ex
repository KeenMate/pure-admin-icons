# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Models.ConstGetCategoriesModel do
  @moduledoc """
  Model representing the result of const.get_categories
  """

  @fields [
    :category_id,
    :code,
    :title,
    :icon_count
  ]

  @enforce_keys @fields

  @derive Jason.Encoder
  defstruct @fields

  @type t() :: %__MODULE__{
    category_id: integer(),
    code: String.t(),
    title: String.t(),
    icon_count: integer()
  }

  use Accessible
end

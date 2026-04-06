# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Models.GetIconCountsBySetModel do
  @moduledoc """
  Model representing the result of public.get_icon_counts_by_set
  """

  @fields [
    :icon_set_code,
    :count
  ]

  @enforce_keys @fields

  @derive Jason.Encoder
  defstruct @fields

  @type t() :: %__MODULE__{
    icon_set_code: String.t(),
    count: integer()
  }

  use Accessible
end

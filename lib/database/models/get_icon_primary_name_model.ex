# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Models.GetIconPrimaryNameModel do
  @moduledoc """
  Model representing the result of public.get_icon_primary_name
  """

  @fields [
    :get_icon_primary_name
  ]

  @enforce_keys @fields

  @derive Jason.Encoder
  defstruct @fields

  @type t() :: %__MODULE__{
    get_icon_primary_name: String.t()
  }

  use Accessible
end

# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Models.GetGroupTranslationsModel do
  @moduledoc """
  Model representing the result of public.get_group_translations
  """

  @fields [
    :get_group_translations
  ]

  @enforce_keys @fields

  @derive Jason.Encoder
  defstruct @fields

  @type t() :: %__MODULE__{
    get_group_translations: map() | list()
  }

  use Accessible
end

# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Models.GetIconByFilenameModel do
  @moduledoc """
  Model representing the result of public.get_icon_by_filename
  """

  @fields [
    :icon_id,
    :size
  ]

  @enforce_keys @fields

  @derive Jason.Encoder
  defstruct @fields

  @type t() :: %__MODULE__{
    icon_id: integer(),
    size: integer()
  }

  use Accessible
end

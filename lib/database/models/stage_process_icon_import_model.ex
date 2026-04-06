# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Models.StageProcessIconImportModel do
  @moduledoc """
  Model representing the result of stage.process_icon_import
  """

  @fields [
    :icons_created,
    :icons_updated,
    :icons_deleted,
    :icons_unchanged,
    :phrases_created,
    :phrase_links_created,
    :phrase_links_deleted,
    :primary_phrases_linked
  ]

  @enforce_keys @fields

  @derive Jason.Encoder
  defstruct @fields

  @type t() :: %__MODULE__{
    icons_created: integer(),
    icons_updated: integer(),
    icons_deleted: integer(),
    icons_unchanged: integer(),
    phrases_created: integer(),
    phrase_links_created: integer(),
    phrase_links_deleted: integer(),
    primary_phrases_linked: integer()
  }

  use Accessible
end

defmodule Database.Models.GetStatsOverviewModel do
  @moduledoc """
  Model representing the result of public.get_stats_overview
  """

  @fields [
    :source_code,
    :period_code,
    :copies,
    :downloads,
    :searches
  ]

  @enforce_keys @fields

  @derive Jason.Encoder
  defstruct @fields

  @type t() :: %__MODULE__{
    source_code: String.t(),
    period_code: String.t(),
    copies: integer(),
    downloads: integer(),
    searches: integer()
  }

  use Accessible
end

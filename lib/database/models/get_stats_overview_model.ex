# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Models.GetStatsOverviewModel do
  @moduledoc """
  Model representing the result of public.get_stats_overview
  """

  @fields [
    :source_code,
    :period_code,
    :action_code,
    :surface_code,
    :format_code,
    :count
  ]

  @enforce_keys @fields

  @derive Jason.Encoder
  defstruct @fields

  @type t() :: %__MODULE__{
    source_code: String.t(),
    period_code: String.t(),
    action_code: String.t(),
    surface_code: String.t(),
    format_code: String.t(),
    count: integer()
  }

  use Accessible
end

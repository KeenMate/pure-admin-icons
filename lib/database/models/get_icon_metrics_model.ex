# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Models.GetIconMetricsModel do
  @moduledoc """
  Model representing the result of public.get_icon_metrics
  """

  @fields [
    :action_code,
    :period_code,
    :count
  ]

  @enforce_keys @fields

  @derive Jason.Encoder
  defstruct @fields

  @type t() :: %__MODULE__{
    action_code: String.t(),
    period_code: String.t(),
    count: integer()
  }

  use Accessible
end

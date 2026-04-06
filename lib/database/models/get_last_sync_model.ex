# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Models.GetLastSyncModel do
  @moduledoc """
  Model representing the result of public.get_last_sync
  """

  @fields [
    :job_run_id,
    :icon_set_code,
    :job_run_type_code,
    :job_status_code,
    :started_at,
    :finished_at,
    :success_data
  ]

  @enforce_keys @fields

  @derive Jason.Encoder
  defstruct @fields

  @type t() :: %__MODULE__{
    job_run_id: integer(),
    icon_set_code: String.t(),
    job_run_type_code: String.t(),
    job_status_code: String.t(),
    started_at: DateTime.t(),
    finished_at: DateTime.t(),
    success_data: map() | list()
  }

  use Accessible
end

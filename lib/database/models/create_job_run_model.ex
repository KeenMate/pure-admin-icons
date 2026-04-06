# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Models.CreateJobRunModel do
  @moduledoc """
  Model representing the result of public.create_job_run
  """

  @fields [
    :create_job_run
  ]

  @enforce_keys @fields

  @derive Jason.Encoder
  defstruct @fields

  @type t() :: %__MODULE__{
    create_job_run: integer()
  }

  use Accessible
end

# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Processors.GetLastSyncProcessor do
  @moduledoc """
  Processor for parsing results from public.get_last_sync
  """

  alias Database.Models.GetLastSyncModel

  @doc """
  Parse the result of the database query into a list of GetLastSyncModel structs
  """
  @spec parse_result({:ok, %Postgrex.Result{}} | {:error, any()}) :: {:ok, [%GetLastSyncModel{}]} | {:error, any()}
  def parse_result({:ok, %Postgrex.Result{rows: rows}}) do
    parsed_results = rows |> Enum.map(&parse_result_row/1)

    errors = parsed_results |> Enum.filter(&(elem(&1, 0) == :error))

    if Enum.empty?(errors) do
      successful_results = parsed_results |> Enum.map(&elem(&1, 1))
      {:ok, successful_results}
    else
      {:error, errors}
    end
  end

  def parse_result({:error, error}), do: {:error, error}

  @doc """
  Parse a single result row into a GetLastSyncModel struct
  """
  @spec parse_result_row(list()) :: {:ok, %GetLastSyncModel{}} | {:error, any()}
  def parse_result_row([job_run_id, icon_set_code, job_run_type_code, job_status_code, started_at, finished_at, success_data]) do
    {:ok, %GetLastSyncModel{
      job_run_id: job_run_id,
      icon_set_code: icon_set_code,
      job_run_type_code: job_run_type_code,
      job_status_code: job_status_code,
      started_at: started_at,
      finished_at: finished_at,
      success_data: success_data
    }}
  end

  def parse_result_row(row) do
    {:error, "Unexpected row format: #{inspect(row)}"}
  end
end

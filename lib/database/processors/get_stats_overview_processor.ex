defmodule Database.Processors.GetStatsOverviewProcessor do
  @moduledoc """
  Processor for parsing results from public.get_stats_overview
  """

  alias Database.Models.GetStatsOverviewModel

  @spec parse_result({:ok, %Postgrex.Result{}} | {:error, any()}) :: {:ok, [%GetStatsOverviewModel{}]} | {:error, any()}
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

  @spec parse_result_row(list()) :: {:ok, %GetStatsOverviewModel{}} | {:error, any()}
  def parse_result_row([source_code, period_code, copies, downloads, searches]) do
    {:ok, %GetStatsOverviewModel{
      source_code: source_code,
      period_code: period_code,
      copies: copies,
      downloads: downloads,
      searches: searches
    }}
  end

  def parse_result_row(row) do
    {:error, "Unexpected row format: #{inspect(row)}"}
  end
end

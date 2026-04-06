# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Processors.GetIconCountsBySetProcessor do
  @moduledoc """
  Processor for parsing results from public.get_icon_counts_by_set
  """

  alias Database.Models.GetIconCountsBySetModel

  @doc """
  Parse the result of the database query into a list of GetIconCountsBySetModel structs
  """
  @spec parse_result({:ok, %Postgrex.Result{}} | {:error, any()}) :: {:ok, [%GetIconCountsBySetModel{}]} | {:error, any()}
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
  Parse a single result row into a GetIconCountsBySetModel struct
  """
  @spec parse_result_row(list()) :: {:ok, %GetIconCountsBySetModel{}} | {:error, any()}
  def parse_result_row([icon_set_code, count]) do
    {:ok, %GetIconCountsBySetModel{
      icon_set_code: icon_set_code,
      count: count
    }}
  end

  def parse_result_row(row) do
    {:error, "Unexpected row format: #{inspect(row)}"}
  end
end

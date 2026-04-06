# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Processors.GetPopularIconsProcessor do
  @moduledoc """
  Processor for parsing results from public.get_popular_icons
  """

  alias Database.Models.GetPopularIconsModel

  @doc """
  Parse the result of the database query into a list of GetPopularIconsModel structs
  """
  @spec parse_result({:ok, %Postgrex.Result{}} | {:error, any()}) :: {:ok, [%GetPopularIconsModel{}]} | {:error, any()}
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
  Parse a single result row into a GetPopularIconsModel struct
  """
  @spec parse_result_row(list()) :: {:ok, %GetPopularIconsModel{}} | {:error, any()}
  def parse_result_row([icon_id, icon_set_code, name, style_code, count]) do
    {:ok, %GetPopularIconsModel{
      icon_id: icon_id,
      icon_set_code: icon_set_code,
      name: name,
      style_code: style_code,
      count: count
    }}
  end

  def parse_result_row(row) do
    {:error, "Unexpected row format: #{inspect(row)}"}
  end
end

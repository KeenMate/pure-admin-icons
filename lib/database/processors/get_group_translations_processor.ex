# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Processors.GetGroupTranslationsProcessor do
  @moduledoc """
  Processor for parsing results from public.get_group_translations
  """

  alias Database.Models.GetGroupTranslationsModel

  @doc """
  Parse the result of the database query into a list of GetGroupTranslationsModel structs
  """
  @spec parse_result({:ok, %Postgrex.Result{}} | {:error, any()}) :: {:ok, [%GetGroupTranslationsModel{}]} | {:error, any()}
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
  Parse a single result row into a GetGroupTranslationsModel struct
  """
  @spec parse_result_row(list()) :: {:ok, %GetGroupTranslationsModel{}} | {:error, any()}
  def parse_result_row([get_group_translations]) do
    {:ok, %GetGroupTranslationsModel{
      get_group_translations: get_group_translations
    }}
  end

  def parse_result_row(row) do
    {:error, "Unexpected row format: #{inspect(row)}"}
  end
end

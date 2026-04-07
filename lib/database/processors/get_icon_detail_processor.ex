# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Processors.GetIconDetailProcessor do
  @moduledoc """
  Processor for parsing results from public.get_icon_detail
  """

  alias Database.Models.GetIconDetailModel

  @doc """
  Parse the result of the database query into a list of GetIconDetailModel structs
  """
  @spec parse_result({:ok, %Postgrex.Result{}} | {:error, any()}) :: {:ok, [%GetIconDetailModel{}]} | {:error, any()}
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
  Parse a single result row into a GetIconDetailModel struct
  """
  @spec parse_result_row(list()) :: {:ok, %GetIconDetailModel{}} | {:error, any()}
  def parse_result_row([icon_id, icon_set_code, icon_set_title, name, style_code, style_color_method, sizes, filenames, ios_identifiers, android_identifiers, categories, phrases]) do
    {:ok, %GetIconDetailModel{
      icon_id: icon_id,
      icon_set_code: icon_set_code,
      icon_set_title: icon_set_title,
      name: name,
      style_code: style_code,
      style_color_method: style_color_method,
      sizes: sizes,
      filenames: filenames,
      ios_identifiers: ios_identifiers,
      android_identifiers: android_identifiers,
      categories: categories,
      phrases: phrases
    }}
  end

  def parse_result_row(row) do
    {:error, "Unexpected row format: #{inspect(row)}"}
  end
end

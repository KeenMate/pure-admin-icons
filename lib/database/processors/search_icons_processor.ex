# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Processors.SearchIconsProcessor do
  @moduledoc """
  Processor for parsing results from public.search_icons
  """

  alias Database.Models.SearchIconsModel

  @doc """
  Parse the result of the database query into a list of SearchIconsModel structs
  """
  @spec parse_result({:ok, %Postgrex.Result{}} | {:error, any()}) :: {:ok, [%SearchIconsModel{}]} | {:error, any()}
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
  Parse a single result row into a SearchIconsModel struct
  """
  @spec parse_result_row(list()) :: {:ok, %SearchIconsModel{}} | {:error, any()}
  def parse_result_row([rank, similarity, icon_id, icon_set_code, icon_set_title, name, style_code, style_color_method, sizes, has_single_source, is_scalable, filenames, platform_identifiers, categories, total_items]) do
    {:ok, %SearchIconsModel{
      rank: rank,
      similarity: similarity,
      icon_id: icon_id,
      icon_set_code: icon_set_code,
      icon_set_title: icon_set_title,
      name: name,
      style_code: style_code,
      style_color_method: style_color_method,
      sizes: sizes,
      has_single_source: has_single_source,
      is_scalable: is_scalable,
      filenames: filenames,
      platform_identifiers: platform_identifiers,
      categories: categories,
      total_items: total_items
    }}
  end

  def parse_result_row(row) do
    {:error, "Unexpected row format: #{inspect(row)}"}
  end
end

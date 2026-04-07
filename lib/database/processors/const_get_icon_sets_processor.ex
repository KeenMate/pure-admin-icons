# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Processors.ConstGetIconSetsProcessor do
  @moduledoc """
  Processor for parsing results from const.get_icon_sets
  """

  alias Database.Models.ConstGetIconSetsModel

  @doc """
  Parse the result of the database query into a list of ConstGetIconSetsModel structs
  """
  @spec parse_result({:ok, %Postgrex.Result{}} | {:error, any()}) :: {:ok, [%ConstGetIconSetsModel{}]} | {:error, any()}
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
  Parse a single result row into a ConstGetIconSetsModel struct
  """
  @spec parse_result_row(list()) :: {:ok, %ConstGetIconSetsModel{}} | {:error, any()}
  def parse_result_row([code, title, license, homepage_url, github_url, styles, sizes, default_size, style_color_methods, icon_count]) do
    {:ok, %ConstGetIconSetsModel{
      code: code,
      title: title,
      license: license,
      homepage_url: homepage_url,
      github_url: github_url,
      styles: styles,
      sizes: sizes,
      default_size: default_size,
      style_color_methods: style_color_methods,
      icon_count: icon_count
    }}
  end

  def parse_result_row(row) do
    {:error, "Unexpected row format: #{inspect(row)}"}
  end
end

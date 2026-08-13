# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Processors.GetIconSetsProcessor do
  @moduledoc """
  Processor for parsing results from public.get_icon_sets
  """

  alias Database.Models.GetIconSetsModel

  @doc """
  Parse the result of the database query into a list of GetIconSetsModel structs
  """
  @spec parse_result({:ok, %Postgrex.Result{}} | {:error, any()}) :: {:ok, [%GetIconSetsModel{}]} | {:error, any()}
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
  Parse a single result row into a GetIconSetsModel struct
  """
  @spec parse_result_row(list()) :: {:ok, %GetIconSetsModel{}} | {:error, any()}
  def parse_result_row([code, title, display_title, description, notes, license, homepage_url, github_url, styles, sizes, default_size, has_single_source, is_scalable, style_color_methods, native_style_names, brand_color, icon_count, last_sync_started_at, last_synced_at]) do
    {:ok, %GetIconSetsModel{
      code: code,
      title: title,
      display_title: display_title,
      description: description,
      notes: notes,
      license: license,
      homepage_url: homepage_url,
      github_url: github_url,
      styles: styles,
      sizes: sizes,
      default_size: default_size,
      has_single_source: has_single_source,
      is_scalable: is_scalable,
      style_color_methods: style_color_methods,
      native_style_names: native_style_names,
      brand_color: brand_color,
      icon_count: icon_count,
      last_sync_started_at: last_sync_started_at,
      last_synced_at: last_synced_at
    }}
  end

  def parse_result_row(row) do
    {:error, "Unexpected row format: #{inspect(row)}"}
  end
end

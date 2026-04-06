# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Processors.StageProcessIconImportProcessor do
  @moduledoc """
  Processor for parsing results from stage.process_icon_import
  """

  alias Database.Models.StageProcessIconImportModel

  @doc """
  Parse the result of the database query into a list of StageProcessIconImportModel structs
  """
  @spec parse_result({:ok, %Postgrex.Result{}} | {:error, any()}) :: {:ok, [%StageProcessIconImportModel{}]} | {:error, any()}
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
  Parse a single result row into a StageProcessIconImportModel struct
  """
  @spec parse_result_row(list()) :: {:ok, %StageProcessIconImportModel{}} | {:error, any()}
  def parse_result_row([icons_created, icons_updated, icons_deleted, icons_unchanged, phrases_created, phrase_links_created, phrase_links_deleted, primary_phrases_linked]) do
    {:ok, %StageProcessIconImportModel{
      icons_created: icons_created,
      icons_updated: icons_updated,
      icons_deleted: icons_deleted,
      icons_unchanged: icons_unchanged,
      phrases_created: phrases_created,
      phrase_links_created: phrase_links_created,
      phrase_links_deleted: phrase_links_deleted,
      primary_phrases_linked: primary_phrases_linked
    }}
  end

  def parse_result_row(row) do
    {:error, "Unexpected row format: #{inspect(row)}"}
  end
end

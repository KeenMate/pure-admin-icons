defmodule PureAdminIcons.SearchMetricsCollector do
  @moduledoc """
  Collects search metrics in memory and flushes to database periodically.

  This avoids hitting the database on every API search request.
  Metrics are flushed every 30 seconds or when the buffer reaches 100 entries.
  """
  use GenServer

  require Logger

  alias Database.DbContext

  @flush_interval :timer.seconds(30)
  @max_buffer_size 100

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Record a search query metric. This is non-blocking.
  """
  def record(query, size, style, result_count, source_code, icon_set_code \\ nil) do
    GenServer.cast(__MODULE__, {:record, query, size, style, result_count, source_code, icon_set_code})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    schedule_flush()
    {:ok, []}
  end

  @impl true
  def handle_cast({:record, query, size, style, result_count, source_code, icon_set_code}, buffer) do
    entry = %{
      query: query,
      size: size,
      style: style,
      result_count: result_count,
      source_code: source_code,
      icon_set_code: icon_set_code
    }

    new_buffer = [entry | buffer]

    if length(new_buffer) >= @max_buffer_size do
      flush(new_buffer)
      {:noreply, []}
    else
      {:noreply, new_buffer}
    end
  end

  @impl true
  def handle_info(:flush, buffer) do
    flush(buffer)
    schedule_flush()
    {:noreply, []}
  end

  @impl true
  def terminate(_reason, buffer) do
    # Flush remaining metrics on shutdown
    flush(buffer)
    :ok
  end

  # Private

  defp schedule_flush do
    Process.send_after(self(), :flush, @flush_interval)
  end

  defp flush([]), do: :ok

  defp flush(buffer) do
    {ok_count, errors} =
      Enum.reduce(buffer, {0, []}, fn entry, {ok, errs} ->
        try do
          # Pass nils (not :eg_value_not_provided) — the generated DbContext
          # filters out :eg_value_not_provided and builds positional $N
          # placeholders, which collapses positions when intermediate args are
          # absent but later ones are present (e.g. size=nil but
          # icon_set_code="fontawesome" lands "fontawesome" in _size int).
          # nil is kept by the filter and arrives as SQL NULL, letting the SP
          # apply its `default null` while preserving argument order.
          case DbContext.track_search(
                 entry.query,
                 entry.result_count,
                 entry.source_code,
                 entry.size,
                 entry.style,
                 entry.icon_set_code
               ) do
            {:ok, _} -> {ok + 1, errs}
            {:error, reason} -> {ok, [{entry, reason} | errs]}
          end
        rescue
          e -> {ok, [{entry, e} | errs]}
        end
      end)

    case errors do
      [] ->
        :ok

      _ ->
        Logger.warning(
          "[SearchMetricsCollector] flush dropped #{length(errors)}/#{length(buffer)} entries; " <>
            "first failure: entry=#{inspect(elem(hd(errors), 0))} reason=#{inspect(elem(hd(errors), 1))}"
        )

        Logger.info("[SearchMetricsCollector] flushed #{ok_count} entries successfully")
    end
  end
end

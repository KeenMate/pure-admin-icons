defmodule PureAdminIcons.SearchMetricsCollector do
  @moduledoc """
  Collects search metrics in memory and flushes to database periodically.

  This avoids hitting the database on every API search request.
  Metrics are flushed every 30 seconds or when the buffer reaches 100 entries.
  """
  use GenServer

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
    # Call track_search for each entry
    Enum.each(buffer, fn entry ->
      DbContext.track_search(
        entry.query,
        entry.result_count,
        entry.source_code,
        entry.size || :eg_value_not_provided,
        entry.style || :eg_value_not_provided,
        entry.icon_set_code || :eg_value_not_provided
      )
    end)
  end
end

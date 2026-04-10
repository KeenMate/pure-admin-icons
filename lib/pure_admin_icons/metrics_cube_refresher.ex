defmodule PureAdminIcons.MetricsCubeRefresher do
  @moduledoc """
  Periodically refreshes the icon metrics cube.
  Only starts when :metrics_cube_interval is configured (dev only).
  """
  use GenServer
  require Logger

  def start_link(_opts) do
    case Application.get_env(:pure_admin_icons, :metrics_cube_interval) do
      nil -> :ignore
      _interval -> GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end
  end

  @impl true
  def init([]) do
    interval = Application.get_env(:pure_admin_icons, :metrics_cube_interval)
    Logger.info("[MetricsCubeRefresher] started, refreshing every #{interval}ms")
    schedule(interval)
    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_info(:refresh, state) do
    Logger.debug("[MetricsCubeRefresher] refreshing cube...")
    Database.DbContext.refresh_icon_metrics_cube()
    schedule(state.interval)
    {:noreply, state}
  end

  defp schedule(interval), do: Process.send_after(self(), :refresh, interval)
end

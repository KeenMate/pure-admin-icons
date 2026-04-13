defmodule PureAdminIconsWeb.AdminStatsLive do
  use PureAdminIconsWeb, :live_view

  alias PureAdminIcons.Icons

  @impl true
  def mount(_params, _session, socket) do
    # Auto-refresh every 30s
    if connected?(socket), do: :timer.send_interval(30_000, :refresh)

    socket =
      socket
      |> assign(page_title: "Stats")
      |> assign(period: "30d")
      |> assign(source: nil)
      |> load_data()

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, load_data(socket)}
  end

  @impl true
  def handle_event("set_period", %{"period" => period}, socket) do
    {:noreply, socket |> assign(period: period) |> load_popular()}
  end

  @impl true
  def handle_event("set_source", %{"source" => source}, socket) do
    source = if source == "", do: nil, else: source
    {:noreply, socket |> assign(source: source) |> load_popular()}
  end

  defp load_data(socket) do
    socket
    |> load_overview()
    |> load_popular()
  end

  defp load_overview(socket) do
    case Icons.stats_overview() do
      {:ok, rows} ->
        # Group by source: %{"web" => %{"1d" => row, "7d" => row, ...}, "api" => %{...}}
        overview =
          rows
          |> Enum.group_by(& &1.source_code)
          |> Map.new(fn {source, rows} ->
            {source, Map.new(rows, &{&1.period_code, &1})}
          end)

        assign(socket, overview: overview)

      {:error, _} ->
        assign(socket, overview: %{})
    end
  end

  defp load_popular(socket) do
    opts = [period: socket.assigns.period, action: "copy", limit: 20]
    opts = if socket.assigns.source, do: [{:source, socket.assigns.source} | opts], else: opts

    case Icons.popular_icons_from_cube(opts) do
      {:ok, icons} -> assign(socket, popular_icons: icons)
      {:error, _} -> assign(socket, popular_icons: [])
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.site_nav />
    <div class="max-w-6xl mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-6">Stats</h1>

      <%!-- Overview cards --%>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        <%= for source <- ["web", "api"] do %>
          <div class="rounded-box bg-base-200 border border-base-300 p-6">
            <h2 class="text-lg font-bold mb-4 capitalize"><%= source %></h2>
            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead>
                  <tr class="text-base-content/60">
                    <th class="text-left pb-2">Period</th>
                    <th class="text-right pb-2">Copies</th>
                    <th class="text-right pb-2">Downloads</th>
                    <th class="text-right pb-2">Searches</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for period <- ["1d", "7d", "30d", "all"] do %>
                    <% row = get_in(@overview, [source, period]) %>
                    <tr class="border-t border-base-300">
                      <td class="py-2 font-medium"><%= period_label(period) %></td>
                      <td class="py-2 text-right tabular-nums"><%= format_count(row && row.copies) %></td>
                      <td class="py-2 text-right tabular-nums"><%= format_count(row && row.downloads) %></td>
                      <td class="py-2 text-right tabular-nums"><%= format_count(row && row.searches) %></td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Popular icons --%>
      <div class="rounded-box bg-base-200 border border-base-300 p-6">
        <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
          <h2 class="text-lg font-bold">Popular Icons (by copies)</h2>
          <div class="flex items-center gap-2">
            <div class="view-toggle">
              <%= for {label, val} <- [{"1d", "1d"}, {"7d", "7d"}, {"30d", "30d"}, {"All", "all"}] do %>
                <button
                  phx-click="set_period"
                  phx-value-period={val}
                  class={["btn-action", if(@period == val, do: "bg-primary text-primary-content", else: "text-base-content/70 hover:text-base-content")]}
                ><%= label %></button>
              <% end %>
            </div>
            <div class="view-toggle">
              <%= for {label, val} <- [{"All", ""}, {"Web", "web"}, {"API", "api"}] do %>
                <button
                  phx-click="set_source"
                  phx-value-source={val}
                  class={["btn-action", if((@source || "") == val, do: "bg-primary text-primary-content", else: "text-base-content/70 hover:text-base-content")]}
                ><%= label %></button>
              <% end %>
            </div>
          </div>
        </div>

        <%= if @popular_icons == [] do %>
          <p class="text-base-content/50 text-center py-8">No data yet for this period.</p>
        <% else %>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="text-base-content/60">
                  <th class="text-left pb-2">#</th>
                  <th class="text-left pb-2">Icon</th>
                  <th class="text-left pb-2">Set</th>
                  <th class="text-left pb-2">Style</th>
                  <th class="text-right pb-2">Count</th>
                </tr>
              </thead>
              <tbody>
                <%= for {icon, idx} <- Enum.with_index(@popular_icons, 1) do %>
                  <tr class="border-t border-base-300">
                    <td class="py-2 text-base-content/50"><%= idx %></td>
                    <td class="py-2 font-medium"><%= icon.name %></td>
                    <td class="py-2"><span class="badge badge-sm" style={PureAdminIcons.IconSets.Color.badge_style(icon.icon_set_code)}><%= icon.icon_set_code %></span></td>
                    <td class="py-2 capitalize text-base-content/70"><%= icon.style_code %></td>
                    <td class="py-2 text-right tabular-nums font-semibold"><%= format_count(icon.count) %></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>

      <footer class="text-center text-base-content/50 text-xs py-8">
        Auto-refreshes every 30s &middot; Cube refreshes every 3 min
      </footer>
    </div>
    """
  end

  defp period_label("1d"), do: "Today"
  defp period_label("7d"), do: "7 days"
  defp period_label("30d"), do: "30 days"
  defp period_label("all"), do: "All time"
  defp period_label(p), do: p

  defp format_count(nil), do: "0"
  defp format_count(0), do: "0"
  defp format_count(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end
  defp format_count(n), do: to_string(n)

end

defmodule PureAdminIconsWeb.AdminStatsLive do
  use PureAdminIconsWeb, :live_view

  import PureAdminIcons.Translations, only: [t: 1]

  alias PureAdminIcons.Icons

  @impl true
  def mount(_params, _session, socket) do
    # Auto-refresh every 30s
    if connected?(socket), do: :timer.send_interval(30_000, :refresh)

    socket =
      socket
      |> assign(page_title: t("stats.headers.pageTitle"))
      |> assign(period: "30d")
      |> assign(source: nil)
      |> assign(action: "download")
      |> load_data()

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, load_data(socket)}
  end

  @impl true
  def handle_event("set_period", %{"period" => period}, socket) do
    {:noreply, socket |> assign(period: period) |> load_breakdowns() |> load_popular()}
  end

  @impl true
  def handle_event("set_source", %{"source" => source}, socket) do
    source = if source == "", do: nil, else: source
    {:noreply, socket |> assign(source: source) |> load_breakdowns() |> load_popular()}
  end

  @impl true
  def handle_event("set_action", %{"action" => action}, socket)
      when action in ~w(copy download) do
    {:noreply, socket |> assign(action: action) |> load_popular()}
  end

  defp load_data(socket) do
    socket
    |> load_overview()
    |> load_breakdowns()
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

  # Per-surface / per-format breakdowns for the currently-selected period.
  # Filtered to copy + download actions (search has no surface/format).
  defp load_breakdowns(socket) do
    period = socket.assigns.period
    source = socket.assigns.source

    case Icons.stats_overview_raw() do
      {:ok, rows} ->
        filtered =
          rows
          |> Enum.filter(fn r ->
            r.period_code == period and r.action_code in ~w(copy download) and
              (is_nil(source) or r.source_code == source)
          end)

        by_surface = sum_by(filtered, & &1.surface_code)
        by_format = sum_by(filtered, & &1.format_code)

        assign(socket, by_surface: by_surface, by_format: by_format)

      {:error, _} ->
        assign(socket, by_surface: [], by_format: [])
    end
  end

  # Group rows by `key_fn`, sum `count`, drop empty keys, sort desc.
  defp sum_by(rows, key_fn) do
    rows
    |> Enum.group_by(key_fn)
    |> Enum.map(fn {k, rs} -> {k, rs |> Enum.map(&(&1.count || 0)) |> Enum.sum()} end)
    |> Enum.reject(fn {k, _} -> is_nil(k) or k == "" end)
    |> Enum.sort_by(fn {_, c} -> -c end)
  end

  defp load_popular(socket) do
    opts = [period: socket.assigns.period, action: socket.assigns.action, limit: 20]
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
      <h1 class="text-3xl font-bold mb-6">{t("stats.headers.pageTitle")}</h1>

      <%!-- Overview cards. API consumers can't generate copy events, so the
           Copies column is rendered for Web only. --%>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        <%= for source <- ["web", "api"] do %>
          <% show_copies = source == "web" %>
          <div class="rounded-box bg-base-200 border border-base-300 p-6">
            <h2 class="text-lg font-bold mb-4 capitalize">{source}</h2>
            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead>
                  <tr class="text-base-content/60">
                    <th class="text-left pb-2">{t("stats.tableHeaders.period")}</th>
                    <%= if show_copies do %>
                      <th class="text-right pb-2">{t("stats.tableHeaders.copies")}</th>
                    <% end %>
                    <th class="text-right pb-2">{t("stats.tableHeaders.downloads")}</th>
                    <th class="text-right pb-2">{t("stats.tableHeaders.searches")}</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for period <- ["1d", "7d", "30d", "all"] do %>
                    <% row = get_in(@overview, [source, period]) %>
                    <tr class="border-t border-base-300">
                      <td class="py-2 font-medium">{period_label(period)}</td>
                      <%= if show_copies do %>
                        <td class="py-2 text-right tabular-nums">
                          {format_count(row && row.copies)}
                        </td>
                      <% end %>
                      <td class="py-2 text-right tabular-nums">
                        {format_count(row && row.downloads)}
                      </td>
                      <td class="py-2 text-right tabular-nums">
                        {format_count(row && row.searches)}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Breakdowns: surface + format for the selected period --%>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        <.breakdown_card
          title={t("stats.headers.bySurface")}
          empty_label={t("stats.empty.noData")}
          rows={@by_surface}
          subtitle={breakdown_subtitle(@period, @source, t("stats.filters.allSources"))}
        />
        <.breakdown_card
          title={t("stats.headers.byFormat")}
          empty_label={t("stats.empty.noData")}
          rows={@by_format}
          subtitle={breakdown_subtitle(@period, @source, t("stats.filters.allSources"))}
        />
      </div>

      <%!-- Popular icons --%>
      <div class="rounded-box bg-base-200 border border-base-300 p-6">
        <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
          <h2 class="text-lg font-bold">{t("stats.headers.popularIcons")}</h2>
          <div class="flex items-center gap-2">
            <div class="view-toggle">
              <%= for {label, val} <- [{"1d", "1d"}, {"7d", "7d"}, {"30d", "30d"}, {"All", "all"}] do %>
                <button
                  phx-click="set_period"
                  phx-value-period={val}
                  class={[
                    "btn-action",
                    if(@period == val,
                      do: "bg-primary text-primary-content",
                      else: "text-base-content/70 hover:text-base-content"
                    )
                  ]}
                >
                  {label}
                </button>
              <% end %>
            </div>
            <div class="view-toggle">
              <%= for {label, val} <- [{t("stats.filters.allSources"), ""}, {t("stats.filters.web"), "web"}, {t("stats.filters.api"), "api"}] do %>
                <button
                  phx-click="set_source"
                  phx-value-source={val}
                  class={[
                    "btn-action",
                    if((@source || "") == val,
                      do: "bg-primary text-primary-content",
                      else: "text-base-content/70 hover:text-base-content"
                    )
                  ]}
                >
                  {label}
                </button>
              <% end %>
            </div>
            <div class="view-toggle">
              <%= for {label, val} <- [{t("stats.filters.byDownload"), "download"}, {t("stats.filters.byCopy"), "copy"}] do %>
                <button
                  phx-click="set_action"
                  phx-value-action={val}
                  class={[
                    "btn-action",
                    if(@action == val,
                      do: "bg-primary text-primary-content",
                      else: "text-base-content/70 hover:text-base-content"
                    )
                  ]}
                >
                  {label}
                </button>
              <% end %>
            </div>
          </div>
        </div>

        <%= if @popular_icons == [] do %>
          <p class="text-base-content/50 text-center py-8">{t("stats.empty.noData")}</p>
        <% else %>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="text-base-content/60">
                  <th class="text-left pb-2">#</th>
                  <th class="text-left pb-2">{t("common.tableHeaders.icon")}</th>
                  <th class="text-left pb-2">{t("common.tableHeaders.set")}</th>
                  <th class="text-left pb-2">{t("common.tableHeaders.style")}</th>
                  <th class="text-right pb-2">{t("stats.tableHeaders.count")}</th>
                </tr>
              </thead>
              <tbody>
                <%= for {icon, idx} <- Enum.with_index(@popular_icons, 1) do %>
                  <tr class="border-t border-base-300">
                    <td class="py-2 text-base-content/50">{idx}</td>
                    <td class="py-2 font-medium">{icon.name}</td>
                    <td class="py-2">
                      <span
                        class="badge badge-sm"
                        style={PureAdminIcons.IconSets.Color.badge_style(icon.icon_set_code)}
                      >
                        {icon.icon_set_code}
                      </span>
                    </td>
                    <td class="py-2 capitalize text-base-content/70">{icon.style_code}</td>
                    <td class="py-2 text-right tabular-nums font-semibold">
                      {format_count(icon.count)}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>

      <footer class="text-center text-base-content/50 text-xs py-8">
        {t("stats.messages.refreshNote")}
      </footer>
    </div>
    """
  end

  defp period_label("1d"), do: t("stats.periods.today")
  defp period_label("7d"), do: t("stats.periods.7d")
  defp period_label("30d"), do: t("stats.periods.30d")
  defp period_label("all"), do: t("stats.periods.allTime")
  defp period_label(p), do: p

  # --- Breakdown card ---------------------------------------------------

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :empty_label, :string, required: true
  attr :rows, :list, required: true, doc: "list of {key, count}"

  defp breakdown_card(assigns) do
    total = assigns.rows |> Enum.map(fn {_, c} -> c end) |> Enum.sum()
    assigns = assign(assigns, :total, total)

    ~H"""
    <div class="rounded-box bg-base-200 border border-base-300 p-6">
      <div class="flex items-baseline justify-between mb-4">
        <h2 class="text-lg font-bold">{@title}</h2>
        <%= if @subtitle do %>
          <span class="text-xs text-base-content/50">{@subtitle}</span>
        <% end %>
      </div>

      <%= if @rows == [] do %>
        <p class="text-base-content/50 text-center py-4">{@empty_label}</p>
      <% else %>
        <div class="space-y-2">
          <%= for {key, count} <- @rows do %>
            <% pct = if @total > 0, do: round(count * 100 / @total), else: 0 %>
            <div>
              <div class="flex items-baseline justify-between text-sm">
                <code class="text-base-content/80">{key}</code>
                <span class="tabular-nums text-base-content/60">
                  {format_count(count)}
                  <span class="text-base-content/40">({pct}%)</span>
                </span>
              </div>
              <div class="h-1.5 bg-base-300 rounded overflow-hidden mt-1">
                <div class="h-full bg-primary" style={"width: #{pct}%;"}></div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # e.g. "30 days · web" or "7 days · all sources"
  defp breakdown_subtitle(period, source, all_label) do
    source_part = source || all_label
    "#{period_label(period)} · #{source_part}"
  end

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

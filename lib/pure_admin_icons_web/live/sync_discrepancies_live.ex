defmodule PureAdminIconsWeb.SyncDiscrepanciesLive do
  use PureAdminIconsWeb, :live_view

  alias PureAdminIcons.Icons

  @impl true
  def mount(_params, _session, socket) do
    syncs = case Icons.get_last_sync() do
      {:ok, syncs} when is_list(syncs) and syncs != [] -> syncs
      {:ok, sync} when is_map(sync) -> [sync]
      _ -> []
    end

    latest_sync = if syncs != [], do: Enum.max_by(syncs, & &1.finished_at, DateTime), else: nil

    # Collect discrepancies from ALL sync runs
    discrepancies =
      syncs
      |> Enum.flat_map(fn sync ->
        items = sync[:discrepancies] || (sync.success_data || %{})["discrepancies"] || []
        Enum.map(items, &Map.put(&1, "icon_set", sync.icon_set_code || "unknown"))
      end)

    socket =
      socket
      |> assign(:sync_run, latest_sync)
      |> assign(:discrepancies, discrepancies)
      |> assign(:grouped, group_discrepancies(discrepancies))

    {:ok, socket}
  end

  defp group_discrepancies(discrepancies) do
    discrepancies
    |> Enum.group_by(& &1["icon_name"])
    |> Enum.sort_by(fn {name, _} -> name end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.site_nav />
    <div class="max-w-4xl mx-auto px-4 py-10">
      <div class="rounded-box bg-base-200 overflow-hidden border border-base-300 p-8">
        <h1 class="text-3xl font-bold mb-2">Sync Discrepancy Report</h1>

        <%= if @sync_run do %>
          <p class="text-sm text-base-content/50 mb-6">
            Last sync: <%= Calendar.strftime(@sync_run.finished_at, "%Y-%m-%d %H:%M:%S UTC") %>
            &bull;
            <span class="font-medium text-warning"><%= length(@discrepancies) %> discrepancies</span>
          </p>

          <%= if length(@discrepancies) == 0 do %>
            <div class="text-center py-12">
              <svg class="w-16 h-16 mx-auto text-success mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <p class="text-base-content/60">No discrepancies found! All metadata matches actual SVG files.</p>
            </div>
          <% else %>
            <div class="mb-4 p-4 bg-warning/10 border border-warning/30 rounded-lg">
              <p class="text-sm text-base-content/80">
                <strong>What are discrepancies?</strong>
                These are cases where an icon set's metadata claims certain sizes/styles exist,
                but the actual SVG files are missing from the repository. This is an upstream data quality issue.
              </p>
            </div>

            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th class="text-base-content/70">Set</th>
                    <th class="text-base-content/70">Icon</th>
                    <th class="text-base-content/70">Missing Files</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for {icon_name, issues} <- @grouped do %>
                    <tr class="hover">
                      <td>
                        <% icon_set = List.first(issues)["icon_set"] || "unknown" %>
                        <span class={["badge badge-sm", icon_set_color(icon_set)]}><%= icon_set %></span>
                      </td>
                      <td class="whitespace-nowrap">
                        <span class="font-medium text-primary"><%= icon_name %></span>
                      </td>
                      <td>
                        <div class="flex flex-wrap gap-1">
                          <%= for issue <- sort_issues(issues) do %>
                            <span class="badge badge-sm badge-error badge-outline">
                              <%= issue["style"] %>/<%= issue["size"] %>px
                            </span>
                          <% end %>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>

            <div class="mt-6 p-4 bg-base-300/50 rounded-lg">
              <h3 class="text-sm font-medium text-base-content mb-2">Summary by Style</h3>
              <div class="flex flex-wrap gap-4">
                <%= for {style, count} <- count_by_style(@discrepancies) do %>
                  <div class="text-sm">
                    <span class="font-medium text-base-content"><%= style %>:</span>
                    <span class="text-base-content/60"><%= count %> missing</span>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        <% else %>
          <div class="text-center py-12">
            <p class="text-base-content/60">No sync has been completed yet.</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp icon_set_color("fluentui"), do: "bg-blue-600 text-white"
  defp icon_set_color("heroicons"), do: "bg-violet-600 text-white"
  defp icon_set_color("lucide"), do: "bg-orange-500 text-white"
  defp icon_set_color("tabler"), do: "bg-cyan-600 text-white"
  defp icon_set_color("fontawesome"), do: "bg-yellow-500 text-black"
  defp icon_set_color(_), do: "bg-base-300 text-base-content"

  defp count_by_style(discrepancies) do
    discrepancies
    |> Enum.group_by(& &1["style"])
    |> Enum.map(fn {style, items} -> {style, length(items)} end)
    |> Enum.sort_by(fn {_, count} -> -count end)
  end

  @style_order %{"regular" => 0, "filled" => 1, "color" => 2, "light" => 3}

  defp sort_issues(issues) do
    Enum.sort_by(issues, fn issue ->
      style_priority = Map.get(@style_order, issue["style"], 99)
      size = issue["size"] || 0
      {style_priority, size}
    end)
  end
end

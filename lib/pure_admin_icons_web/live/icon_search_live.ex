defmodule PureAdminIconsWeb.IconSearchLive do
  use PureAdminIconsWeb, :live_view

  alias PureAdminIcons.Icons
  alias PureAdminIcons.Icons.Icon
  alias Phoenix.LiveView.JS

  import PureAdminIconsWeb.Components.PlatformIcons

  @per_page 30

  @impl true
  def mount(_params, _session, socket) do
    # Get preferences from connect params (passed from JS localStorage)
    # get_connect_params returns nil during static render, so we use defaults
    connect_params = get_connect_params(socket) || %{}
    view_mode = connect_params["view_mode"] || "grid"
    platform_prefs = connect_params["platform_prefs"] || %{}
    platform_prefs = atomize_keys(platform_prefs)
    default_prefs = %{ios: true, android: true, react: true, svelte: true, filename: true}
    platform_prefs = Map.merge(default_prefs, platform_prefs)

    {last_sync_at, discrepancy_count} = case Icons.get_last_sync() do
      {:ok, syncs} when is_list(syncs) and syncs != [] ->
        # Multiple icon sets: get latest finish time and sum discrepancies
        latest = Enum.max_by(syncs, & &1.finished_at, DateTime)
        total_discrepancies = Enum.sum(Enum.map(syncs, &((&1.success_data || %{})["discrepancy_count"] || 0)))
        {latest.finished_at, total_discrepancies}
      {:ok, sync} when is_map(sync) ->
        {sync.finished_at, (sync.success_data || %{})["discrepancy_count"] || 0}
      _ ->
        {nil, 0}
    end
    icon_sets = Icons.list_icon_sets()

    {:ok,
     socket
     |> assign(icon_count: Icons.count())
     |> assign(icon_sets: icon_sets)
     |> assign(platform_prefs: platform_prefs)
     |> assign(view_mode: view_mode)
     |> assign(last_sync_at: last_sync_at)
     |> assign(discrepancy_count: discrepancy_count)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = params["q"] || ""
    styles = parse_list(params["styles"])
    sizes = parse_sizes(params["sizes"])
    icon_sets = parse_list(params["set"])
    page = parse_page(params["page"])

    assigns = %{selected_styles: styles, selected_sizes: sizes, selected_icon_sets: icon_sets, page: page}
    icons = search_icons(query, assigns)
    total_count = case icons do
      [first | _] -> first.total_items
      [] -> 0
    end
    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
     assign(socket,
       query: query,
       selected_styles: styles,
       selected_sizes: sizes,
       selected_icon_sets: icon_sets,
       page: page,
       icons: icons,
       total_count: total_count,
       total_pages: total_pages,
       selected_icon: nil
     )}
  end

  defp parse_page(nil), do: 1
  defp parse_page(""), do: 1
  defp parse_page(page_str) do
    case Integer.parse(page_str) do
      {page, _} when page > 0 -> page
      _ -> 1
    end
  end

  defp parse_list(nil), do: []
  defp parse_list(""), do: []
  defp parse_list(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
  end

  defp parse_sizes(nil), do: []
  defp parse_sizes(""), do: []
  defp parse_sizes(sizes_str) do
    sizes_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&String.to_integer/1)
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, q: query, page: 1))}
  end

  def handle_event("toggle_size", %{"size" => size}, socket) do
    size = String.to_integer(size)
    sizes = socket.assigns.selected_sizes
    new_sizes = if size in sizes, do: List.delete(sizes, size), else: [size | sizes]
    {:noreply, push_patch(socket, to: build_path(socket, sizes: new_sizes, page: 1))}
  end

  def handle_event("toggle_style", %{"style" => style}, socket) do
    styles = socket.assigns.selected_styles
    new_styles = if style in styles, do: List.delete(styles, style), else: [style | styles]
    {:noreply, push_patch(socket, to: build_path(socket, styles: new_styles, page: 1))}
  end

  def handle_event("toggle_icon_set", %{"set" => icon_set}, socket) do
    sets = socket.assigns.selected_icon_sets
    new_sets = if icon_set in sets, do: List.delete(sets, icon_set), else: [icon_set | sets]
    {:noreply, push_patch(socket, to: build_path(socket, icon_sets: new_sets, page: 1))}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, styles: [], sizes: [], icon_sets: [], page: 1))}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, page: String.to_integer(page)))}
  end

  def handle_event("select_icon", %{"id" => id}, socket) do
    icon = Enum.find(socket.assigns.icons, &(to_string(&1.icon_id) == id))
    # Fetch metrics for this icon (from raw table, fast enough for single icon)
    metrics = if icon, do: Icons.icon_metrics(icon.icon_id), else: %{}
    {:noreply, assign(socket, selected_icon: icon, icon_metrics: metrics)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, selected_icon: nil)}
  end

  def handle_event("toggle_platform", %{"platform" => platform}, socket) do
    prefs = socket.assigns.platform_prefs
    new_prefs = Map.update!(prefs, String.to_existing_atom(platform), &(!&1))

    socket =
      socket
      |> assign(:platform_prefs, new_prefs)
      |> push_event("save_platform_prefs", new_prefs)

    {:noreply, socket}
  end

  def handle_event("toggle_view", %{"mode" => mode}, socket) do
    socket =
      socket
      |> assign(view_mode: mode)
      |> push_event("save_view_mode", %{mode: mode})

    {:noreply, socket}
  end

  def handle_event("track_download", %{"icon-id" => icon_id, "size" => size}, socket) do
    # Track download asynchronously (don't block the UI)
    Task.start(fn ->
      Icons.track_action(String.to_integer(icon_id), "download", size: String.to_integer(size))
    end)
    {:noreply, socket}
  end

  def handle_event("track_copy", %{"icon-id" => icon_id, "platform" => platform} = params, socket) do
    # Track copy asynchronously
    size = params["size"]
    Task.start(fn ->
      opts = [platform: platform]
      opts = if size, do: [{:size, String.to_integer(size)} | opts], else: opts
      Icons.track_action(String.to_integer(icon_id), "copy", opts)
    end)
    {:noreply, socket}
  end

  defp atomize_keys(map) do
    Map.new(map, fn {k, v} ->
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, v}
    end)
  end

  defp build_path(socket, overrides) do
    query = Keyword.get(overrides, :q, socket.assigns.query)
    styles = Keyword.get(overrides, :styles, socket.assigns.selected_styles)
    sizes = Keyword.get(overrides, :sizes, socket.assigns.selected_sizes)
    icon_sets = Keyword.get(overrides, :icon_sets, socket.assigns.selected_icon_sets)
    page = Keyword.get(overrides, :page, socket.assigns.page)

    params =
      []
      |> maybe_add_param("q", query, "")
      |> maybe_add_list("set", icon_sets)
      |> maybe_add_list("styles", styles)
      |> maybe_add_list("sizes", Enum.map(sizes, &to_string/1))
      |> maybe_add_param("page", page, 1)

    case params do
      [] -> "/"
      _ -> "/?" <> URI.encode_query(params)
    end
  end

  defp maybe_add_param(params, _key, value, default) when value == default, do: params
  defp maybe_add_param(params, key, value, _default), do: [{key, value} | params]

  defp maybe_add_list(params, _key, []), do: params
  defp maybe_add_list(params, key, list) do
    [{key, Enum.join(Enum.sort(list), ",")} | params]
  end

  defp search_icons(query, assigns) do
    # Use page-based pagination (new DbContext approach)
    opts = [limit: @per_page, page: assigns.page]

    opts =
      case assigns.selected_styles do
        [] -> opts
        styles -> [{:styles, styles} | opts]
      end

    opts =
      case assigns.selected_sizes do
        [] -> opts
        sizes -> [{:sizes, sizes} | opts]
      end

    opts =
      case assigns.selected_icon_sets do
        [] -> opts
        icon_sets -> [{:icon_sets, icon_sets} | opts]
      end

    case Icons.search(query, opts) do
      {:ok, results} -> results
      {:error, _} -> []
    end
  end

  defp get_total_count(query, assigns) do
    opts = []

    opts =
      case assigns.selected_styles do
        [] -> opts
        styles -> [{:styles, styles} | opts]
      end

    opts =
      case assigns.selected_sizes do
        [] -> opts
        sizes -> [{:sizes, sizes} | opts]
      end

    opts =
      case assigns.selected_icon_sets do
        [] -> opts
        icon_sets -> [{:icon_sets, icon_sets} | opts]
      end

    Icons.search_count(query, opts)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <!-- Hidden element for metrics tracking from JS -->
      <div id="metrics-tracker" phx-hook="MetricsTracker" class="hidden"></div>

      <%!-- Nav --%>
      <div class="flex items-center justify-between px-4 sm:px-6 lg:px-8 py-3">
        <Layouts.logo />
        <div class="flex items-center gap-2">
          <a href="/docs" class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium text-base-content/80 hover:text-primary hover:bg-base-200 transition-colors">
            <.icon name="hero-book-open" class="size-4" /> Docs
          </a>
          <a href="/docs/api" class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium text-base-content/80 hover:text-primary hover:bg-base-200 transition-colors">
            <.icon name="hero-code-bracket" class="size-4" /> API
          </a>
          <a href="https://keenmate.com" target="_blank" rel="noreferrer" class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium text-base-content/80 hover:text-primary hover:bg-base-200 transition-colors">
            <.icon name="hero-building-office-2" class="size-4" /> Keenmate
          </a>
        </div>
      </div>

      <%!-- Hero with search and filters --%>
      <div class="hero-gradient py-6 px-4 border-b border-base-300">
        <div class="max-w-5xl mx-auto text-center mb-4">
          <p class="text-base-content/70">Search <span class="font-semibold text-primary"><%= @icon_count %></span> icons from <span class="font-semibold text-primary"><%= length(@icon_sets) %></span> icon sets</p>
          <p class="text-sm text-base-content/50 mt-1">
            Using Claude? Try our <a href="https://www.npmjs.com/package/@keenmate/fluentui-icons-mcp" target="_blank" rel="noreferrer" class="text-primary hover:underline">MCP server</a> to search icons directly from Claude Desktop or Claude Code.
          </p>
        </div>

        <div class="max-w-5xl mx-auto">
        <!-- Search Bar -->
        <form phx-change="search" phx-submit="search" class="mb-6">
          <div class="relative">
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <svg class="h-5 w-5 text-base-content/50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </div>
            <input
              type="text"
              name="query"
              value={@query}
              placeholder="Search icons (e.g., 'pen', 'calendar', 'add')..."
              phx-debounce="300"
              class="w-full pl-10 pr-4 py-3 rounded-lg border border-base-300 shadow-sm search-glow text-base-content text-lg"
              autofocus
            />
          </div>
        </form>

        <!-- Filters -->
        <div class="flex flex-wrap gap-6 mb-6 items-center">
          <!-- Style Filter -->
          <div class="flex items-center gap-3">
            <span class="text-base font-medium text-base-content">Styles:</span>
            <%= for style <- ["regular", "filled", "color", "light"] do %>
              <label class="inline-flex items-center cursor-pointer gap-1.5">
                <input
                  type="checkbox"
                  phx-click="toggle_style"
                  phx-value-style={style}
                  checked={style in @selected_styles}
                  class="w-5 h-5 rounded border-base-300 focus:ring-primary"
                />
                <span class="text-base text-base-content/70 capitalize"><%= style %></span>
              </label>
            <% end %>
          </div>

          <!-- Size Filters -->
          <div class="flex items-center gap-3">
            <span class="text-base font-medium text-base-content">Sizes:</span>
            <%= for size <- [16, 20, 24, 28, 32, 48] do %>
              <label class="inline-flex items-center cursor-pointer gap-1.5">
                <input
                  type="checkbox"
                  phx-click="toggle_size"
                  phx-value-size={size}
                  checked={size in @selected_sizes}
                  class="w-5 h-5 rounded border-base-300 focus:ring-primary"
                />
                <span class="text-base text-base-content/70"><%= size %></span>
              </label>
            <% end %>
          </div>

          <!-- Icon Set Filter -->
          <div class="flex items-center gap-3">
            <span class="text-base font-medium text-base-content">Sets:</span>
            <%= for icon_set <- @icon_sets do %>
              <label class="inline-flex items-center cursor-pointer gap-1.5">
                <input
                  type="checkbox"
                  phx-click="toggle_icon_set"
                  phx-value-set={icon_set.code}
                  checked={icon_set.code in @selected_icon_sets}
                  class="w-5 h-5 rounded border-base-300 focus:ring-primary"
                />
                <span class="text-base text-base-content/70" title={"#{icon_set.icon_count} icons"}><%= icon_set.title %></span>
              </label>
            <% end %>
          </div>

          <!-- Clear Filters -->
          <%= if @selected_styles != [] || @selected_sizes != [] || @selected_icon_sets != [] do %>
            <button
              phx-click="clear_filters"
              class="text-base text-primary hover:text-primary"
            >
              Clear filters
            </button>
          <% end %>
        </div>

        <!-- Active Filters Display -->
        <%= if @selected_styles != [] || @selected_sizes != [] || @selected_icon_sets != [] do %>
          <div class="flex flex-wrap gap-2 mb-4 items-center">
            <span class="text-sm text-base-content/70">Active filters:</span>
            <%= for icon_set <- Enum.sort(@selected_icon_sets) do %>
              <button
                type="button"
                phx-click="toggle_icon_set"
                phx-value-set={icon_set}
                class="inline-flex items-center gap-1 px-2 py-1 rounded-full text-sm bg-secondary text-primary-content hover:bg-secondary"
              >
                <%= icon_set %>
                <span class="text-lg leading-none">&times;</span>
              </button>
            <% end %>
            <%= for style <- Enum.sort(@selected_styles) do %>
              <button
                type="button"
                phx-click="toggle_style"
                phx-value-style={style}
                class="inline-flex items-center gap-1 px-2 py-1 rounded-full text-sm bg-primary text-primary-content hover:opacity-80"
              >
                <%= style %>
                <span class="text-lg leading-none">&times;</span>
              </button>
            <% end %>
            <%= for size <- Enum.sort(@selected_sizes) do %>
              <button
                type="button"
                phx-click="toggle_size"
                phx-value-size={size}
                class="inline-flex items-center gap-1 px-2 py-1 rounded-full text-sm bg-primary text-primary-content hover:opacity-80"
              >
                <%= size %>px
                <span class="text-lg leading-none">&times;</span>
              </button>
            <% end %>
          </div>
        <% end %>

        <!-- Results Count, View Toggle & Pager -->
        <div class="flex justify-between items-center mb-4">
          <div class="text-sm text-base-content/70">
            Showing <%= (@page - 1) * 30 + 1 %>-<%= min(@page * 30, @total_count) %> of <%= @total_count %> icons
          </div>
          <div class="flex items-center gap-4">
            <!-- View Toggle - CSS controls active state based on data-view-mode -->
            <div class="flex items-center gap-1 bg-base-200 rounded-lg p-1" id="view-mode" phx-hook="ViewMode">
              <button
                phx-click="toggle_view"
                phx-value-mode="grid"
                class="btn-grid px-3 py-1.5 rounded text-sm flex items-center gap-1.5"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
                </svg>
                Grid
              </button>
              <button
                phx-click="toggle_view"
                phx-value-mode="list"
                class="btn-list px-3 py-1.5 rounded text-sm flex items-center gap-1.5"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16" />
                </svg>
                List
              </button>
            </div>
            <.pager current_page={@page} total_pages={@total_pages} />
          </div>
        </div>
        </div>
      </div>

      <%!-- Content --%>
      <main class="px-4 py-6 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-7xl">
        <!-- Icon Display (Grid or List) - Both rendered, CSS controls visibility -->
        <div id="icon-display" phx-hook="IconColorFilter">
          <div class="view-grid">
            <.icon_grid icons={@icons} selected_styles={@selected_styles} selected_sizes={@selected_sizes} selected_icon_sets={@selected_icon_sets} platform_prefs={@platform_prefs} />
          </div>
          <div class="view-list">
            <.icon_list icons={@icons} platform_prefs={@platform_prefs} selected_sizes={@selected_sizes} />
          </div>
        </div>

        <!-- Bottom Pager -->
        <%= if @total_pages > 1 do %>
          <div class="flex justify-end mt-6">
            <.pager current_page={@page} total_pages={@total_pages} />
          </div>
        <% end %>

        <!-- Empty State -->
        <%= if @query != "" and @icons == [] do %>
          <div class="text-center py-16">
            <svg class="h-16 w-16 text-base-content/50 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <p class="text-base-content/70">No icons found for "<%= @query %>"</p>
            <p class="text-sm text-base-content/50 mt-1">Try a different search term or adjust your filters</p>
          </div>
        <% end %>

        <!-- Footer -->
        <footer class="mt-12 py-6 border-t border-base-300 text-sm text-base-content/70">
          <div class="flex flex-col sm:flex-row justify-between items-center gap-2">
            <div>
              Made by <a href="https://keenmate.com" rel="noreferrer" referrerpolicy="origin" class="text-primary hover:underline">Keenmate</a>
            </div>
            <%= if @last_sync_at do %>
              <div class="text-xs text-base-content/50 flex items-center gap-2">
                <span>Last synced: <%= format_sync_time(@last_sync_at) %></span>
                <%= if @discrepancy_count > 0 do %>
                  <a href="/sync/discrepancies" class="text-warning hover:opacity-80 hover:underline">
                    (<%= @discrepancy_count %> discrepancies)
                  </a>
                <% end %>
              </div>
            <% end %>
          </div>
        </footer>
        </div>
      </main>

      <!-- Icon Detail Modal -->
      <%= if @selected_icon do %>
        <.icon_modal icon={@selected_icon} platform_prefs={@platform_prefs} metrics={@icon_metrics} />
      <% end %>
    </div>
    """
  end

  defp icon_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
      <!-- Backdrop -->
      <div class="fixed inset-0 bg-black/60 transition-opacity" phx-click="close_modal"></div>

      <!-- Modal -->
      <div class="flex min-h-full items-center justify-center p-4">
        <div class="relative bg-base-200 rounded-xl shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
          <!-- Close button -->
          <button
            phx-click="close_modal"
            class="absolute top-4 right-4 text-base-content/50 hover:text-base-content/70 z-10"
          >
            <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          <div class="p-6">
            <!-- Header -->
            <div class="text-center mb-6">
              <h2 class="text-2xl font-bold text-base-content" id="modal-title"><%= @icon.name %></h2>
              <div class="flex justify-center gap-2 mt-2">
                <span class="inline-block px-2.5 py-1 rounded text-sm font-medium badge-set"><%= @icon.icon_set_code %></span>
                <span class="inline-block px-2.5 py-1 rounded text-sm font-medium badge-style capitalize"><%= @icon.style_code %></span>
              </div>

              <!-- Stats -->
              <% copies = Map.get(@metrics, "copy", 0) %>
              <% downloads = Map.get(@metrics, "download", 0) %>
              <% total = copies + downloads %>
              <%= if total > 0 do %>
                <div class="flex justify-center gap-3 mt-3">
                  <div class="px-3 py-1.5 bg-base-200 rounded-lg text-center">
                    <div class="text-lg font-semibold text-primary"><%= format_number(copies) %></div>
                    <div class="text-xs text-primary">copies</div>
                  </div>
                  <div class="px-3 py-1.5 bg-base-200 rounded-lg text-center">
                    <div class="text-lg font-semibold text-success"><%= format_number(downloads) %></div>
                    <div class="text-xs text-success">downloads</div>
                  </div>
                  <div class="px-3 py-1.5 bg-base-200 rounded-lg text-center">
                    <div class="text-lg font-semibold text-base-content"><%= format_number(total) %></div>
                    <div class="text-xs text-base-content/70">total</div>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Color Picker -->
            <div class="mb-4 flex items-center gap-3" id={"color-picker-#{@icon.icon_id}"} phx-hook="ColorPicker"
                 data-update-trigger={:erlang.phash2(@platform_prefs)}>
              <label class="text-sm font-medium text-base-content">Preview Color:</label>
              <input type="color" value="#212121"
                     class="color-input w-10 h-10 rounded cursor-pointer border border-base-300" />
              <input type="text" value="#212121"
                     class="color-text w-24 px-2 py-1 text-sm font-mono border border-base-300 rounded search-glow"
                     maxlength="7" placeholder="#000000" />
            </div>

            <!-- Icon Sizes Preview with Download -->
            <div class="mb-6">
              <h3 class="text-sm font-medium text-base-content mb-3">Available Sizes</h3>
              <div class="flex flex-wrap gap-4 justify-center items-end"
                   id={"icon-preview-#{@icon.icon_id}"}
                   phx-hook="InlineSvg"
                   data-color="#212121"
                   data-urls={Jason.encode!(Enum.map(@icon.sizes, &Icon.svg_url(@icon, &1)))}>
                <%= for size <- @icon.sizes do %>
                  <div class="flex flex-col items-center">
                    <div class="svg-container bg-base-100 rounded-lg p-3 border border-base-300 flex items-center justify-center"
                         data-size={size}
                         style={"width: #{min(size + 24, 96)}px; height: #{min(size + 24, 96)}px;"}>
                      <!-- SVG loaded by JavaScript -->
                    </div>
                    <span class="text-xs text-base-content/70 mt-1"><%= size %>px</span>
                    <a href={Icon.svg_url(@icon, size)}
                       download={Icon.svg_filename(@icon, size)}
                       phx-click="track_download"
                       phx-value-icon-id={@icon.icon_id}
                       phx-value-size={size}
                       title="Download SVG"
                       class="mt-1 p-1.5 text-primary hover:text-primary hover:bg-base-200 rounded-md transition-colors">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                      </svg>
                    </a>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Platform Identifiers -->
            <div class="space-y-4">
              <div class="flex items-center justify-between">
                <h3 class="text-sm font-medium text-base-content">Platform Identifiers</h3>
              </div>

              <!-- Platform Toggle Checkboxes -->
              <div class="flex flex-wrap gap-4 pb-4 border-b border-base-300" id="platform-prefs" phx-hook="PlatformPrefs">
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={@platform_prefs.ios}
                    phx-click="toggle_platform"
                    phx-value-platform="ios"
                    class="w-4 h-4 rounded border-base-300 focus:ring-primary"
                  />
                  <.platform_icon name="ios" class="w-4 h-4 text-base-content/70" />
                  <span class="text-sm text-base-content/70">iOS</span>
                </label>
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={@platform_prefs.android}
                    phx-click="toggle_platform"
                    phx-value-platform="android"
                    class="w-4 h-4 rounded border-base-300 focus:ring-primary"
                  />
                  <.platform_icon name="android" class="w-4 h-4 text-base-content/70" />
                  <span class="text-sm text-base-content/70">Android</span>
                </label>
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={@platform_prefs.react}
                    phx-click="toggle_platform"
                    phx-value-platform="react"
                    class="w-4 h-4 rounded border-base-300 focus:ring-primary"
                  />
                  <.platform_icon name="react" class="w-4 h-4 text-base-content/70" />
                  <span class="text-sm text-base-content/70">React</span>
                </label>
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={@platform_prefs.svelte}
                    phx-click="toggle_platform"
                    phx-value-platform="svelte"
                    class="w-4 h-4 rounded border-base-300 focus:ring-primary"
                  />
                  <.platform_icon name="svelte" class="w-4 h-4 text-base-content/70" />
                  <span class="text-sm text-base-content/70">Svelte</span>
                </label>
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={@platform_prefs.filename}
                    phx-click="toggle_platform"
                    phx-value-platform="filename"
                    class="w-4 h-4 rounded border-base-300 focus:ring-primary"
                  />
                  <.platform_icon name="filename" class="w-4 h-4 text-base-content/70" />
                  <span class="text-sm text-base-content/70">Filename</span>
                </label>
              </div>

              <!-- iOS -->
              <%= if @platform_prefs.ios do %>
                <div class="bg-base-100 rounded-lg p-4">
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-sm font-medium text-base-content/70 flex items-center gap-1.5">
                      <.platform_icon name="ios" class="w-4 h-4" />
                      iOS (Swift)
                    </span>
                  </div>
                  <div class="space-y-1">
                    <%= for {size, id} <- @icon.ios_identifiers || %{} do %>
                      <div class="flex items-center justify-between bg-base-200 rounded px-3 py-2 border border-base-300">
                        <code class="text-sm text-primary"><%= id %></code>
                        <button
                          type="button"
                          phx-click={JS.dispatch("phx:copy", to: "#ios-#{@icon.icon_id}-#{size}")}
                          class="text-xs text-base-content/70 hover:text-base-content px-2 py-1 rounded hover:bg-base-200"
                        >Copy</button>
                        <span id={"ios-#{@icon.icon_id}-#{size}"} class="hidden"><%= id %></span>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- Android -->
              <%= if @platform_prefs.android do %>
                <div class="bg-base-100 rounded-lg p-4">
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-sm font-medium text-base-content/70 flex items-center gap-1.5">
                      <.platform_icon name="android" class="w-4 h-4" />
                      Android (Kotlin/Java)
                    </span>
                  </div>
                  <div class="space-y-1">
                    <%= for {size, id} <- @icon.android_identifiers || %{} do %>
                      <div class="flex items-center justify-between bg-base-200 rounded px-3 py-2 border border-base-300">
                        <code class="text-sm text-success"><%= id %></code>
                        <button
                          type="button"
                          phx-click={JS.dispatch("phx:copy", to: "#android-#{@icon.icon_id}-#{size}")}
                          class="text-xs text-base-content/70 hover:text-base-content px-2 py-1 rounded hover:bg-base-200"
                        >Copy</button>
                        <span id={"android-#{@icon.icon_id}-#{size}"} class="hidden"><%= id %></span>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- React -->
              <%= if @platform_prefs.react do %>
                <div class="bg-base-100 rounded-lg p-4">
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-sm font-medium text-base-content/70 flex items-center gap-1.5">
                      <.platform_icon name="react" class="w-4 h-4" />
                      React (@fluentui/react-icons)
                    </span>
                  </div>
                  <div class="space-y-1">
                    <%= for size <- @icon.sizes do %>
                      <div class="flex items-center justify-between bg-base-200 rounded px-3 py-2 border border-base-300">
                        <code id={"react-#{@icon.icon_id}-#{size}"} class="text-sm text-purple-600"><%= react_identifier(@icon, size) %></code>
                        <button
                          type="button"
                          phx-click={JS.dispatch("phx:copy", to: "#react-#{@icon.icon_id}-#{size}")}
                          class="text-xs text-base-content/70 hover:text-base-content px-2 py-1 rounded hover:bg-base-200"
                        >Copy</button>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- Svelte -->
              <%= if @platform_prefs.svelte do %>
                <div class="bg-base-100 rounded-lg p-4" id={"svelte-section-#{@icon.icon_id}"} phx-hook="SvelteColor"
                     data-name={@icon.name |> String.downcase() |> String.replace(" ", "_")}
                     data-style={@icon.style_code}
                     data-sizes={Jason.encode!(@icon.sizes)}>
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-sm font-medium text-base-content/70 flex items-center gap-1.5">
                      <.platform_icon name="svelte" class="w-4 h-4" />
                      Svelte (<a href="https://svelte-fluentui.keenmate.dev" target="_blank" rel="noreferrer" referrerpolicy="unsafe-url" class="text-primary hover:underline">svelte-fluentui</a>)
                    </span>
                    <label class="flex items-center gap-1.5 text-xs text-base-content/70 cursor-pointer">
                      <input type="checkbox" class="svelte-include-color w-3.5 h-3.5 rounded border-base-300" />
                      Include color
                    </label>
                  </div>
                  <div class="space-y-1 svelte-code-list">
                    <%= for size <- @icon.sizes do %>
                      <div class="flex items-center justify-between bg-base-200 rounded px-3 py-2 border border-base-300">
                        <code id={"svelte-#{@icon.icon_id}-#{size}"} class="text-sm text-orange-600" data-size={size}><%= svelte_identifier(@icon, size) %></code>
                        <button
                          type="button"
                          phx-click={JS.dispatch("phx:copy", to: "#svelte-#{@icon.icon_id}-#{size}")}
                          class="text-xs text-base-content/70 hover:text-base-content px-2 py-1 rounded hover:bg-base-200"
                        >Copy</button>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- Filename -->
              <%= if @platform_prefs.filename do %>
                <div class="bg-base-100 rounded-lg p-4" id={"filename-section-#{@icon.icon_id}"} phx-hook="FilenameTemplate"
                     data-name={@icon.name} data-style={@icon.style_code} data-sizes={Jason.encode!(@icon.sizes)}>
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-sm font-medium text-base-content/70 flex items-center gap-1.5">
                      <.platform_icon name="filename" class="w-4 h-4" />
                      Filename (local copy)
                    </span>
                  </div>
                  <div class="mb-1 text-xs text-base-content/70">
                    <span class="font-medium">Placeholders:</span>
                    <code class="bg-base-300 px-1 rounded">{"{filename}"}</code>
                    <code class="bg-base-300 px-1 rounded">{"{name}"}</code>
                    <code class="bg-base-300 px-1 rounded">{"{name_snake}"}</code>
                    <code class="bg-base-300 px-1 rounded">{"{name_pascal}"}</code>
                    <code class="bg-base-300 px-1 rounded">{"{name_kebab}"}</code>
                    <code class="bg-base-300 px-1 rounded">{"{size}"}</code>
                    <code class="bg-base-300 px-1 rounded">{"{style}"}</code>
                  </div>
                  <div class="mb-3">
                    <input type="text" id={"filename-template-input-#{@icon.icon_id}"}
                           class="w-full px-3 py-2 text-sm border border-base-300 rounded search-glow"
                           placeholder={"/my/assets/{filename}"} />
                  </div>
                  <div id={"filename-results-#{@icon.icon_id}"} class="space-y-1">
                    <!-- Populated by JavaScript -->
                  </div>
                </div>
              <% end %>
            </div>

          </div>
        </div>
      </div>
    </div>
    """
  end

  defp pager(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <button
        :if={@current_page > 1}
        phx-click="change_page"
        phx-value-page={@current_page - 1}
        class="px-3 py-1 rounded bg-base-300 hover:bg-base-300 text-sm"
      >Previous</button>
      <button
        :if={@current_page <= 1}
        disabled
        class="px-3 py-1 rounded bg-base-200 text-base-content/50 text-sm cursor-not-allowed"
      >Previous</button>

      <span class="text-sm text-base-content/70">
        Page <%= @current_page %> of <%= @total_pages %>
      </span>

      <button
        :if={@current_page < @total_pages}
        phx-click="change_page"
        phx-value-page={@current_page + 1}
        class="px-3 py-1 rounded bg-base-300 hover:bg-base-300 text-sm"
      >Next</button>
      <button
        :if={@current_page >= @total_pages}
        disabled
        class="px-3 py-1 rounded bg-base-200 text-base-content/50 text-sm cursor-not-allowed"
      >Next</button>
    </div>
    """
  end

  defp icon_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
      <%= for icon <- @icons do %>
        <div
          phx-click="select_icon"
          phx-value-id={icon.icon_id}
          class="icon-card bg-base-200 rounded-lg p-4 cursor-pointer group flex flex-col"
        >
          <!-- Icon Preview -->
          <div class="w-16 h-16 mx-auto mb-3 flex items-center justify-center flex-shrink-0">
            <span class="inline-svg-icon inline-flex items-center justify-center w-10 h-10" data-svg-url={Icon.svg_url(icon, default_size(icon.sizes))}></span>
          </div>

          <!-- Icon Name -->
          <div class="text-sm font-semibold text-base-content text-center truncate mb-auto" title={icon.name}>
            <%= icon.name %>
          </div>

          <!-- Tags at bottom -->
          <div class="mt-3 pt-3 border-t border-base-300">
            <!-- Icon Set & Style -->
            <div class="flex flex-wrap justify-center gap-1 mb-1">
              <span class="badge badge-sm badge-secondary"><%= icon.icon_set_code %></span>
              <span class="badge badge-sm badge-neutral"><%= icon.style_code %></span>
            </div>
            <!-- Sizes -->
            <div class="flex flex-wrap justify-center gap-1">
              <%= for size <- icon.sizes do %>
                <span class="badge badge-sm badge-ghost"><%= size %>px</span>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp icon_list(assigns) do
    assigns = assign(assigns, :display_sizes, if(assigns.selected_sizes == [], do: [16, 20, 24, 28, 32, 48], else: Enum.sort(assigns.selected_sizes)))
    ~H"""
    <div class="bg-base-200 rounded-lg border border-base-300">
      <div>
        <table class="w-full text-sm">
          <thead class="bg-base-200 border-b-2 border-base-300 sticky-table-header">
            <tr>
              <th class="w-16 px-4 py-4 text-left font-semibold text-base-content text-base sticky bg-base-200 z-20" style="top: var(--sticky-header-height, 0px)">Icon</th>
              <th class="px-4 py-4 text-left font-semibold text-base-content text-base sticky bg-base-200 z-20" style="top: var(--sticky-header-height, 0px)">Name</th>
              <th class="w-24 px-4 py-4 text-center font-semibold text-base-content text-base sticky bg-base-200 z-20" style="top: var(--sticky-header-height, 0px)">Style</th>
              <%= for size <- @display_sizes do %>
                <th class="w-16 px-2 py-4 text-center font-semibold text-base-content text-sm sticky bg-base-200 z-20" style="top: var(--sticky-header-height, 0px)"><%= size %></th>
              <% end %>
            </tr>
          </thead>
          <tbody class="divide-y divide-base-300">
            <%= for icon <- @icons do %>
              <tr
                phx-click="select_icon"
                phx-value-id={icon.icon_id}
                class="hover:bg-base-200 cursor-pointer transition-colors group"
              >
                <td class="px-4 py-3">
                  <span class="inline-svg-icon inline-flex items-center justify-center w-6 h-6" data-svg-url={Icon.svg_url(icon, default_size(icon.sizes))}></span>
                </td>
                <td class="px-4 py-3 font-medium text-base-content"><%= icon.name %></td>
                <td class="px-4 py-3 text-center">
                  <span class="px-2 py-0.5 rounded text-xs bg-base-200 text-base-content/70 capitalize"><%= icon.style_code %></span>
                </td>
                <%= for size <- @display_sizes do %>
                  <td class="px-2 py-3 text-center relative">
                    <%= if size in icon.sizes do %>
                      <span class="text-success font-black text-lg">✓</span>
                      <div class="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity bg-base-200">
                        <div class="flex gap-0.5">
                          <%= for platform <- preferred_platforms(@platform_prefs, 2) do %>
                            <button
                              type="button"
                              class={"p-1.5 rounded cursor-pointer hover:bg-base-300 hover:scale-110 active:scale-95 transition-transform #{platform_color(platform)}"}
                              title={"Copy #{platform} identifier for size #{size}"}
                              phx-click={JS.dispatch("phx:copy_text", detail: %{text: get_platform_id_for_size(icon, platform, size)})}
                              phx-value-stop-propagation="true"
                            >
                              <.platform_icon name={to_string(platform)} class="w-4 h-4" />
                            </button>
                          <% end %>
                        </div>
                      </div>
                    <% else %>
                      <span class="text-base-content/50">✗</span>
                    <% end %>
                  </td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp default_size(sizes) do
    if 24 in sizes, do: 24, else: hd(sizes)
  end

  defp get_ios_id(icon) do
    size = default_size(icon.sizes) |> to_string()
    Map.get(icon.ios_identifiers, size, "N/A")
  end

  defp get_android_id(icon) do
    size = default_size(icon.sizes) |> to_string()
    Map.get(icon.android_identifiers, size, "N/A")
  end

  # Get the first N enabled platforms from user preferences
  defp preferred_platforms(prefs, count) do
    [:ios, :android, :react, :svelte, :filename]
    |> Enum.filter(&Map.get(prefs, &1, false))
    |> Enum.take(count)
  end

  defp platform_color(:ios), do: "text-primary"
  defp platform_color(:android), do: "text-success"
  defp platform_color(:react), do: "text-cyan-600"
  defp platform_color(:svelte), do: "text-orange-600"
  defp platform_color(:filename), do: "text-base-content/70"
  defp platform_color(_), do: "text-base-content/70"

  defp get_platform_id(icon, :ios), do: get_ios_id(icon)
  defp get_platform_id(icon, :android), do: get_android_id(icon)
  defp get_platform_id(icon, :react), do: react_identifier(icon, default_size(icon.sizes))
  defp get_platform_id(icon, :svelte), do: svelte_identifier(icon, default_size(icon.sizes))
  defp get_platform_id(icon, :filename), do: Icon.svg_filename(icon, default_size(icon.sizes))
  defp get_platform_id(_, _), do: "N/A"

  # Get platform identifier for a specific size
  defp get_platform_id_for_size(icon, :ios, size) do
    Map.get(icon.ios_identifiers, to_string(size), "N/A")
  end
  defp get_platform_id_for_size(icon, :android, size) do
    Map.get(icon.android_identifiers, to_string(size), "N/A")
  end
  defp get_platform_id_for_size(icon, :react, size), do: react_identifier(icon, size)
  defp get_platform_id_for_size(icon, :svelte, size), do: svelte_identifier(icon, size)
  defp get_platform_id_for_size(icon, :filename, size), do: Icon.svg_filename(icon, size)
  defp get_platform_id_for_size(_, _, _), do: "N/A"

  # React: PascalCase component import (e.g., <ArrowClockwise24Regular />)
  defp react_identifier(icon, size) do
    name = icon.name |> String.replace(" ", "")
    style = icon.style_code |> String.capitalize()
    "<#{name}#{size}#{style} />"
  end

  # Svelte: snake_case with props (e.g., <Icon name="arrow_clockwise" size={24} variant="regular" />)
  defp svelte_identifier(icon, size) do
    name = icon.name |> String.downcase() |> String.replace(" ", "_")
    ~s(<Icon name="#{name}" size={#{size}} variant="#{icon.style_code}" />)
  end

  # Format numbers with k/m suffixes (1000 -> 1k, 3400 -> 3.4k, 1500000 -> 1.5m)
  defp format_number(n) when n >= 1_000_000 do
    formatted = Float.round(n / 1_000_000, 1)
    if formatted == trunc(formatted), do: "#{trunc(formatted)}m", else: "#{formatted}m"
  end

  defp format_number(n) when n >= 1_000 do
    formatted = Float.round(n / 1_000, 1)
    if formatted == trunc(formatted), do: "#{trunc(formatted)}k", else: "#{formatted}k"
  end

  defp format_number(n), do: to_string(n)

  # Format sync timestamp as relative time or date
  defp format_sync_time(nil), do: "Never"

  defp format_sync_time(%DateTime{} = dt) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, dt, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)} minutes ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)} hours ago"
      diff_seconds < 604_800 -> "#{div(diff_seconds, 86400)} days ago"
      true -> Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
    end
  end
end

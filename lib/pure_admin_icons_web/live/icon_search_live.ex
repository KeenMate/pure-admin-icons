defmodule PureAdminIconsWeb.IconSearchLive do
  use PureAdminIconsWeb, :live_view

  alias PureAdminIcons.Icons
  alias PureAdminIcons.Icons.Icon
  alias Phoenix.LiveView.JS

  import PureAdminIconsWeb.Components.PlatformIcons

  @per_page 30

  # Load preview presets from JSON config at compile time
  @preview_presets :pure_admin_icons
                   |> :code.priv_dir()
                   |> Path.join("preview_presets.json")
                   |> File.read!()
                   |> Jason.decode!()
  @external_resource Path.join(:code.priv_dir(:pure_admin_icons), "preview_presets.json")
  defp preview_presets, do: @preview_presets

  defp preset_button_style(%{"bg" => "checker", "color" => color}) do
    "background-image: repeating-conic-gradient(#e5e7eb 0% 25%, #fff 0% 50%); background-size: 8px 8px; color: #{color};"
  end

  defp preset_button_style(%{"bg" => bg, "color" => color}) do
    "background-color: #{bg}; color: #{color};"
  end

  @impl true
  def mount(_params, _session, socket) do
    require Logger
    Logger.debug("[timing] mount start, connected=#{connected?(socket)}")
    # Get preferences from connect params (passed from JS localStorage)
    # get_connect_params returns nil during static render, so we use defaults
    connect_params = get_connect_params(socket) || %{}
    Logger.debug("[timing] connect_params: view_mode=#{connect_params["view_mode"]}, icon_list_size=#{connect_params["icon_list_size"]}")
    view_mode = connect_params["view_mode"] || "grid"
    icon_list_size = connect_params["icon_list_size"] || 32

    # Per-icon-set platform prefs: %{icon_set_code => %{platform => bool}}
    # Migration: if old shape (flat map) exists, treat it as the default for all sets
    raw_prefs = connect_params["platform_prefs"] || %{}
    platform_prefs_by_set = parse_platform_prefs(raw_prefs)

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
    all_styles = icon_sets |> Enum.flat_map(& &1.styles) |> Enum.uniq() |> Enum.sort()
    all_sizes = icon_sets |> Enum.flat_map(& &1.sizes) |> Enum.uniq() |> Enum.sort()

    {:ok,
     socket
     |> assign(icon_count: Icons.count())
     |> assign(icon_sets: icon_sets)
     |> assign(all_styles: all_styles)
     |> assign(all_sizes: all_sizes)
     |> assign(platform_prefs_by_set: platform_prefs_by_set)
     |> assign(platform_prefs: default_platform_prefs())
     |> assign(view_mode: view_mode)
     |> assign(icon_list_size: icon_list_size)
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

    # On very first connected mount with no filter params, restore from localStorage
    {styles, sizes, icon_sets} =
      if connected?(socket) and no_filter_params?(params) and not Map.get(socket.assigns, :filters_initialized, false) do
        connect_params = get_connect_params(socket) || %{}
        saved_styles = List.wrap(connect_params["filter_styles"] || []) |> Enum.filter(&is_binary/1)
        saved_sizes = List.wrap(connect_params["filter_sizes"] || []) |> Enum.map(&to_int/1) |> Enum.reject(&is_nil/1)
        saved_sets = List.wrap(connect_params["filter_icon_sets"] || []) |> Enum.filter(&is_binary/1)
        {saved_styles, saved_sizes, saved_sets}
      else
        {styles, sizes, icon_sets}
      end

    assigns = %{selected_styles: styles, selected_sizes: sizes, selected_icon_sets: icon_sets, page: page}
    icons = search_icons(query, assigns)
    total_count = case icons do
      [first | _] -> first.total_items
      [] -> 0
    end
    total_pages = max(1, ceil(total_count / @per_page))

    # Compute available styles/sizes based on selected icon sets
    {available_styles, available_sizes} =
      case icon_sets do
        [] ->
          {socket.assigns.all_styles, socket.assigns.all_sizes}
        selected ->
          filtered = Enum.filter(socket.assigns.icon_sets, &(&1.code in selected))
          {
            filtered |> Enum.flat_map(& &1.styles) |> Enum.uniq() |> Enum.sort(),
            filtered |> Enum.flat_map(& &1.sizes) |> Enum.uniq() |> Enum.sort()
          }
      end

    page_title = if query != "", do: "#{query} — Icon Search", else: nil

    {:noreply,
     assign(socket,
       page_title: page_title,
       query: query,
       selected_styles: styles,
       selected_sizes: sizes,
       selected_icon_sets: icon_sets,
       available_styles: available_styles,
       available_sizes: available_sizes,
       page: page,
       icons: icons,
       total_count: total_count,
       total_pages: total_pages,
       selected_icon: nil,
       filters_initialized: true
     )
     |> maybe_save_filters(styles, sizes, icon_sets)}
  end

  defp no_filter_params?(params) do
    is_nil(params["styles"]) and is_nil(params["sizes"]) and is_nil(params["set"])
  end

  defp to_int(val) when is_integer(val), do: val
  defp to_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> nil
    end
  end
  defp to_int(_), do: nil

  defp maybe_save_filters(socket, styles, sizes, icon_sets) do
    if connected?(socket) do
      push_event(socket, "save_filters", %{
        styles: styles,
        sizes: sizes,
        icon_sets: icon_sets
      })
    else
      socket
    end
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

    # Prune styles/sizes that aren't available in the new icon set selection
    {new_styles, new_sizes} =
      case new_sets do
        [] ->
          {socket.assigns.selected_styles, socket.assigns.selected_sizes}
        selected ->
          filtered = Enum.filter(socket.assigns.icon_sets, &(&1.code in selected))
          avail_styles = filtered |> Enum.flat_map(& &1.styles) |> Enum.uniq()
          avail_sizes = filtered |> Enum.flat_map(& &1.sizes) |> Enum.uniq()
          {
            Enum.filter(socket.assigns.selected_styles, &(&1 in avail_styles)),
            Enum.filter(socket.assigns.selected_sizes, &(&1 in avail_sizes))
          }
      end

    {:noreply, push_patch(socket, to: build_path(socket, icon_sets: new_sets, styles: new_styles, sizes: new_sizes, page: 1))}
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
    # Load this icon set's prefs (or defaults)
    prefs = if icon, do: prefs_for_set(socket.assigns.platform_prefs_by_set, icon.icon_set_code), else: default_platform_prefs()
    {:noreply, assign(socket, selected_icon: icon, icon_metrics: metrics, platform_prefs: prefs)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, selected_icon: nil)}
  end

  def handle_event("toggle_platform", %{"platform" => platform}, socket) do
    icon = socket.assigns.selected_icon
    if icon do
      prefs = socket.assigns.platform_prefs
      key = String.to_existing_atom(platform)
      new_prefs = Map.update!(prefs, key, &(!&1))

      # Update per-set storage
      new_by_set = Map.put(socket.assigns.platform_prefs_by_set, icon.icon_set_code, new_prefs)

      socket =
        socket
        |> assign(:platform_prefs, new_prefs)
        |> assign(:platform_prefs_by_set, new_by_set)
        |> push_event("save_platform_prefs", new_by_set)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
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

  # Default platform preferences for any new icon set
  defp default_platform_prefs do
    %{ios: true, android: true, react: true, vue: true, svelte: true, cssclass: true, htmltag: true, filename: true}
  end

  # Get prefs for a specific icon set, falling back to defaults
  defp prefs_for_set(prefs_by_set, icon_set_code) do
    case Map.get(prefs_by_set, icon_set_code) do
      nil -> default_platform_prefs()
      prefs -> Map.merge(default_platform_prefs(), prefs)
    end
  end

  # Parse the platform_prefs from connect_params.
  # Supports both new shape (%{set => prefs}) and legacy flat shape (%{platform => bool}).
  defp parse_platform_prefs(raw) when is_map(raw) and map_size(raw) == 0, do: %{}
  defp parse_platform_prefs(raw) when is_map(raw) do
    # Detect legacy shape: top-level keys are platform names (ios/android/...) not set codes
    legacy_keys = ["ios", "android", "react", "vue", "svelte", "cssclass", "htmltag", "filename"]
    is_legacy = raw |> Map.keys() |> Enum.any?(&(&1 in legacy_keys))

    if is_legacy do
      # Migrate flat shape: apply to all known sets
      flat = atomize_pref_values(raw)
      ["fluentui", "fontawesome", "heroicons", "lucide", "tabler"]
      |> Enum.map(fn set -> {set, flat} end)
      |> Map.new()
    else
      # New shape: %{set => prefs}
      Map.new(raw, fn {set, prefs} -> {set, atomize_pref_values(prefs)} end)
    end
  end
  defp parse_platform_prefs(_), do: %{}

  defp atomize_pref_values(prefs) when is_map(prefs) do
    Map.new(prefs, fn {k, v} ->
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      val = if is_binary(v), do: v == "true", else: v
      {key, val}
    end)
  end
  defp atomize_pref_values(_), do: %{}

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
    <div class="min-h-screen flex flex-col">
      <!-- Hidden element for metrics tracking from JS -->
      <div id="metrics-tracker" phx-hook="MetricsTracker" class="hidden"></div>

      <Layouts.site_nav />

      <%!-- Hero with search and filters --%>
      <div class="hero-gradient py-6 px-4 border-b border-base-300">
        <div class="max-w-5xl mx-auto text-center mb-4">
          <p class="text-base-content/70">Search <span class="font-semibold text-primary"><%= @icon_count %></span> icons from <span class="font-semibold text-primary"><%= length(@icon_sets) %></span> icon sets</p>
          <p class="text-sm text-base-content/50 mt-1">
            Using Claude? Try our <a href="https://www.npmjs.com/package/@keenmate/fluentui-icons-mcp" target="_blank" rel="noreferrer" class="text-primary hover:underline">MCP server</a> to search icons directly from Claude Desktop or Claude Code.
          </p>
        </div>

        <div class="max-w-5xl mx-auto">
        <!-- Search Bar + View Toggle -->
        <div class="flex gap-3 mb-6 items-center">
          <form phx-change="search" phx-submit="search" class="flex-1">
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
                class="w-full pl-10 pr-4 py-3 rounded-lg border border-base-content/25 bg-base-content/10 shadow-sm search-glow text-base-content text-lg"
                autofocus
              />
            </div>
          </form>
          <div class="flex items-center gap-2">
            <button
              phx-click={JS.toggle(to: "#filters-panel", in: "fade-in-scale", out: "fade-out-scale")}
              class={["px-3 py-2 rounded text-sm flex items-center gap-1.5 cursor-pointer transition-colors border", if(@selected_styles != [] || @selected_sizes != [] || @selected_icon_sets != [], do: "bg-primary text-primary-content border-primary", else: "bg-base-200 text-base-content/70 hover:text-base-content border-base-300")]}
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z" />
              </svg>
              Filters
            </button>
            <div class="flex items-center gap-1 bg-base-200 rounded-lg p-1" id="view-mode" phx-hook="ViewMode">
              <button
                phx-click="toggle_view"
                phx-value-mode="grid"
                class={["px-3 py-2 rounded text-sm flex items-center gap-1.5 cursor-pointer transition-colors", if(@view_mode == "grid", do: "bg-primary text-primary-content", else: "text-base-content/70 hover:text-base-content")]}
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
                </svg>
                Grid
              </button>
              <button
                phx-click="toggle_view"
                phx-value-mode="list"
                class={["px-3 py-2 rounded text-sm flex items-center gap-1.5 cursor-pointer transition-colors", if(@view_mode == "list", do: "bg-primary text-primary-content", else: "text-base-content/70 hover:text-base-content")]}
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16" />
                </svg>
                List
              </button>
            </div>
          </div>
        </div>

        <!-- Filters (collapsible) -->
        <div id="filters-panel" class="mb-6 p-4 bg-base-200/50 rounded-lg border border-base-300 space-y-4" style="display: none;">
          <!-- Icon Set Filter -->
          <div class="flex flex-wrap items-center gap-x-3 gap-y-2">
            <span class="text-base font-medium text-base-content min-w-14">Sets:</span>
            <%= for icon_set <- @icon_sets do %>
              <label class="inline-flex items-center cursor-pointer gap-1.5">
                <input
                  type="checkbox"
                  phx-click="toggle_icon_set"
                  phx-value-set={icon_set.code}
                  checked={icon_set.code in @selected_icon_sets}
                  class="w-5 h-5 rounded border-base-content/25 focus:ring-primary"
                />
                <span class="text-base text-base-content/70" title={"#{icon_set.icon_count} icons"}><%= icon_set.title %></span>
              </label>
            <% end %>
          </div>

          <!-- Style Filter -->
          <div class="flex flex-wrap items-center gap-x-3 gap-y-2">
            <span class="text-base font-medium text-base-content min-w-14">Styles:</span>
            <%= for style <- @available_styles do %>
              <label class="inline-flex items-center cursor-pointer gap-1.5">
                <input
                  type="checkbox"
                  phx-click="toggle_style"
                  phx-value-style={style}
                  checked={style in @selected_styles}
                  class="w-5 h-5 rounded border-base-content/25 focus:ring-primary"
                />
                <span class="text-base text-base-content/70 capitalize"><%= style %></span>
              </label>
            <% end %>
          </div>

          <!-- Size Filters -->
          <div class="flex flex-wrap items-center gap-x-3 gap-y-2">
            <span class="text-base font-medium text-base-content min-w-14">Sizes:</span>
            <%= for size <- @available_sizes do %>
              <label class="inline-flex items-center cursor-pointer gap-1.5">
                <input
                  type="checkbox"
                  phx-click="toggle_size"
                  phx-value-size={size}
                  checked={size in @selected_sizes}
                  class="w-5 h-5 rounded border-base-content/25 focus:ring-primary"
                />
                <span class="text-base text-base-content/70"><%= size %></span>
              </label>
            <% end %>
          </div>

        </div>

        <!-- Active Filters Display -->
        <%= if @selected_styles != [] || @selected_sizes != [] || @selected_icon_sets != [] do %>
          <div class="flex flex-wrap gap-2 mb-4 items-center">
            <span class="text-sm font-medium text-base-content/70">Active filters:</span>
            <%= for icon_set <- Enum.sort(@selected_icon_sets) do %>
              <button
                type="button"
                phx-click="toggle_icon_set"
                phx-value-set={icon_set}
                class={["badge badge-sm gap-1 cursor-pointer hover:opacity-80", icon_set_color(icon_set)]}
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
                class="badge badge-sm badge-neutral gap-1 cursor-pointer hover:opacity-80"
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
                class="badge badge-sm badge-ghost gap-1 cursor-pointer hover:opacity-80"
              >
                <%= size %>px
                <span class="text-lg leading-none">&times;</span>
              </button>
            <% end %>
            <button
              phx-click="clear_filters"
              class="text-sm text-primary hover:text-primary/80 ml-1"
            >
              Clear all
            </button>
          </div>
        <% end %>

        <!-- Results Count, Icon Size Slider & Pager -->
        <div class="flex flex-wrap justify-between items-center mb-4 gap-3">
          <div class="text-sm text-base-content/70">
            Showing <%= (@page - 1) * 30 + 1 %>-<%= min(@page * 30, @total_count) %> of <%= @total_count %> icons
          </div>
          <div class="flex items-center gap-3">
            <div class={["flex items-center gap-2", if(@view_mode != "list", do: "hidden")]} id="icon-size-slider" phx-hook="IconSizeSlider">
              <svg class="w-4 h-4 text-base-content/50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0H8M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
              </svg>
              <input type="range" min="24" max="64" value={@icon_list_size} step="4"
                     class="icon-size-range range range-xs range-primary w-20 cursor-pointer" />
              <span class="icon-size-label text-xs text-base-content/50 w-8"><%= @icon_list_size %>px</span>
            </div>
            <.pager current_page={@page} total_pages={@total_pages} />
          </div>
        </div>
        </div>
      </div>

      <%!-- Content --%>
      <main class="px-4 py-6 sm:px-6 lg:px-8 flex-1">
        <div class="mx-auto max-w-7xl">
        <!-- Icon Display (Grid or List) - Both rendered, CSS controls visibility -->
        <div id="icon-display" phx-hook="IconColorFilter">
          <div class="view-grid">
            <.icon_grid icons={@icons} selected_styles={@selected_styles} selected_sizes={@selected_sizes} selected_icon_sets={@selected_icon_sets} platform_prefs={@platform_prefs} />
          </div>
          <div class="view-list">
            <.icon_list icons={@icons} platform_prefs={@platform_prefs} selected_sizes={@selected_sizes} available_sizes={@available_sizes} icon_list_size={@icon_list_size} />
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

        </div>
      </main>

      <!-- Footer -->
      <footer class="border-t border-base-300 bg-base-200/50">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-6">
            <!-- Branding -->
            <div>
              <Layouts.logo class="text-lg" />
              <p class="text-xs text-base-content/50 mt-2">
                Search <%= @icon_count %> open-source SVG icons from <%= length(@icon_sets) %> icon sets.
              </p>
              <p class="text-xs text-base-content/40 mt-1">
                Made by <a href="https://keenmate.com" rel="noreferrer" referrerpolicy="origin" class="text-primary hover:underline">KeenMate</a>
              </p>
            </div>

            <!-- Links -->
            <div>
              <h4 class="text-sm font-semibold text-base-content mb-2">Resources</h4>
              <ul class="space-y-1 text-xs text-base-content/60">
                <li><a href="/docs/api" class="hover:text-primary">API Documentation</a></li>
                <li><a href="/docs/mcp" class="hover:text-primary">MCP Server</a></li>
                <li><a href="/docs/llms" class="hover:text-primary">LLM Integration</a></li>
                <li><a href="/api/health" class="hover:text-primary">Health Check</a></li>
              </ul>
            </div>

            <!-- Icon Sets -->
            <div>
              <h4 class="text-sm font-semibold text-base-content mb-2">Icon Sets</h4>
              <ul class="space-y-1 text-xs text-base-content/60">
                <%= for icon_set <- @icon_sets do %>
                  <li>
                    <a href={icon_set.homepage_url} target="_blank" rel="noreferrer" class="hover:text-primary">
                      <%= icon_set.title %>
                    </a>
                    <span class="text-base-content/30">(<%= icon_set.icon_count %>)</span>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>

          <!-- Bottom bar -->
          <div class="mt-6 pt-4 border-t border-base-300/50 flex flex-col sm:flex-row justify-between items-center gap-2 text-xs text-base-content/40">
            <span>Icon SVGs retain their original licenses.</span>
            <%= if @last_sync_at do %>
              <div class="flex items-center gap-2">
                <span>Last synced: <%= format_sync_time(@last_sync_at) %></span>
                <%= if @discrepancy_count > 0 do %>
                  <a href="/sync/discrepancies" class="text-warning hover:opacity-80 hover:underline">
                    (<%= @discrepancy_count %> discrepancies)
                  </a>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </footer>

      <!-- Icon Detail Modal -->
      <%= if @selected_icon do %>
        <.icon_modal icon={@selected_icon} platform_prefs={@platform_prefs} metrics={@icon_metrics} />
      <% end %>
    </div>
    """
  end

  defp icon_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true" phx-window-keydown="close_modal" phx-key="Escape">
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
                <span class={["inline-block px-2.5 py-1 rounded text-sm font-medium", icon_set_color(@icon.icon_set_code)]}><%= @icon.icon_set_code %></span>
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

            <!-- Preview Presets & Custom Color -->
            <div class="mb-4" id={"color-picker-#{@icon.icon_id}"} phx-hook="ColorPicker"
                 data-update-trigger={:erlang.phash2(@platform_prefs)}
                 data-presets={Jason.encode!(preview_presets())}
                 data-color-method={@icon.style_color_method || "fill"}
                 data-icon-set={@icon.icon_set_code}>
              <%= if @icon.style_color_method == "multicolor" do %>
                <div class="flex items-center gap-3">
                  <label class="text-sm font-medium text-base-content">Preview:</label>
                  <span class="text-sm text-base-content/50 italic">Multicolor icon — not recolorable</span>
                </div>
              <% else %>
                <div class="flex flex-wrap items-center gap-2 mb-2">
                  <label class="text-sm font-medium text-base-content">Preview:</label>
                  <div class="preview-preset-active inline-flex items-center gap-2"><!-- active preset rendered here by JS --></div>
                  <button type="button" class="preview-preset-toggle px-3 py-1.5 rounded text-sm font-medium cursor-pointer border border-base-300 hover:bg-base-200">More ▾</button>
                  <button type="button" class="preview-copy-css px-3 py-1.5 rounded text-sm font-medium cursor-pointer border border-base-300 hover:bg-base-200 inline-flex items-center gap-1.5" title="Copy CSS to use these colors in your project">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" /></svg>
                    Copy CSS
                  </button>
                </div>
                <div class="preview-preset-list flex flex-wrap items-center gap-2 mb-2" style="display: none;">
                  <%= for preset <- preview_presets() do %>
                    <button
                      type="button"
                      data-preset={preset["key"]}
                      class="preview-preset px-2.5 py-1 rounded text-xs font-medium cursor-pointer border border-base-300 hover:scale-105 transition-transform"
                      style={preset_button_style(preset)}
                    ><%= preset["label"] %></button>
                  <% end %>
                  <div class="custom-presets-container contents"></div>
                </div>
                <div class="preview-custom-area space-y-2 p-3 rounded-lg bg-base-200/50 border border-base-300">
                  <div class="flex flex-wrap items-center gap-3">
                    <label class="text-sm text-base-content/70 font-medium">Custom:</label>
                    <div class="flex items-center gap-2">
                      <span class="text-xs text-base-content/50">Icon</span>
                      <input type="color" value="#212121"
                             class="color-input w-8 h-8 rounded cursor-pointer border border-base-300" />
                      <input type="text" value="#212121"
                             class="color-text w-20 px-2 py-1 text-xs font-mono border border-base-300 rounded"
                             maxlength="7" placeholder="#000000" />
                    </div>
                    <div class="flex items-center gap-2">
                      <span class="text-xs text-base-content/50">Bg</span>
                      <input type="color" value="#ffffff"
                             class="bg-color-input w-8 h-8 rounded cursor-pointer border border-base-300" />
                      <input type="text" value="#ffffff"
                             class="bg-color-text w-20 px-2 py-1 text-xs font-mono border border-base-300 rounded"
                             maxlength="7" placeholder="#ffffff" />
                    </div>
                    <span class={["text-xs px-2 py-0.5 rounded", color_method_class(@icon.style_color_method)]}>
                      <%= color_method_label(@icon.style_color_method) %>
                    </span>
                  </div>
                  <div class="flex items-center gap-2">
                    <input type="text"
                           class="custom-preset-name w-40 px-2 py-1 text-xs border border-base-300 rounded"
                           placeholder="Name your preset..." maxlength="20" />
                    <button type="button" class="custom-preset-save px-3 py-1 rounded text-xs font-medium cursor-pointer bg-primary text-primary-content hover:opacity-80">
                      Save as preset
                    </button>
                  </div>
                </div>
              <% end %>
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
                    <div class="svg-container bg-white rounded-lg p-3 border border-base-300 flex items-center justify-center"
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
                <% {react_pkg, _} = react_package(@icon) %>
                <% {vue_pkg, _} = vue_package(@icon) %>
                <% {svelte_pkg, _} = svelte_package(@icon) %>
                <%= if react_pkg do %>
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
                <% end %>
                <%= if vue_pkg do %>
                  <label class="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={@platform_prefs.vue}
                      phx-click="toggle_platform"
                      phx-value-platform="vue"
                      class="w-4 h-4 rounded border-base-300 focus:ring-primary"
                    />
                    <.platform_icon name="vue" class="w-4 h-4 text-base-content/70" />
                    <span class="text-sm text-base-content/70">Vue</span>
                  </label>
                <% end %>
                <%= if svelte_pkg do %>
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
                <% end %>
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
                <% {cssclass_pkg, _} = cssclass_package(@icon) %>
                <%= if cssclass_pkg do %>
                  <label class="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={@platform_prefs.cssclass}
                      phx-click="toggle_platform"
                      phx-value-platform="cssclass"
                      class="w-4 h-4 rounded border-base-300 focus:ring-primary"
                    />
                    <.platform_icon name="cssclass" class="w-4 h-4 text-base-content/70" />
                    <span class="text-sm text-base-content/70">CSS Class</span>
                  </label>
                  <label class="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={@platform_prefs.htmltag}
                      phx-click="toggle_platform"
                      phx-value-platform="htmltag"
                      class="w-4 h-4 rounded border-base-300 focus:ring-primary"
                    />
                    <.platform_icon name="htmltag" class="w-4 h-4 text-base-content/70" />
                    <span class="text-sm text-base-content/70">HTML Tag</span>
                  </label>
                <% end %>
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
                <% {react_pkg_name, react_pkg_url} = react_package(@icon) %>
                <div class="bg-base-100 rounded-lg p-4">
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-sm font-medium text-base-content/70 flex items-center gap-1.5">
                      <.platform_icon name="react" class="w-4 h-4" />
                      React (<%= if react_pkg_url do %><a href={react_pkg_url} target="_blank" rel="noreferrer" class="text-primary hover:underline"><%= react_pkg_name %></a><% else %><%= react_pkg_name %><% end %>)
                    </span>
                  </div>
                  <div class="space-y-1">
                    <%= for size <- react_identifier_sizes(@icon) do %>
                      <div class="flex items-center justify-between bg-base-200 rounded px-3 py-2 border border-base-300">
                        <code id={"react-#{@icon.icon_id}-#{size}"} class="text-sm text-purple-600 whitespace-pre-line"><%= react_identifier(@icon, size) %></code>
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

              <!-- Vue -->
              <%= if @platform_prefs.vue do %>
                <% {vue_pkg_name, vue_pkg_url} = vue_package(@icon) %>
                <%= if vue_pkg_name do %>
                  <div class="bg-base-100 rounded-lg p-4">
                    <div class="flex items-center justify-between mb-2">
                      <span class="text-sm font-medium text-base-content/70 flex items-center gap-1.5">
                        <.platform_icon name="vue" class="w-4 h-4" />
                        Vue (<%= if vue_pkg_url do %><a href={vue_pkg_url} target="_blank" rel="noreferrer" class="text-primary hover:underline"><%= vue_pkg_name %></a><% else %><%= vue_pkg_name %><% end %>)
                      </span>
                    </div>
                    <div class="space-y-1">
                      <%= for size <- vue_identifier_sizes(@icon) do %>
                        <div class="flex items-center justify-between bg-base-200 rounded px-3 py-2 border border-base-300">
                          <code id={"vue-#{@icon.icon_id}-#{size}"} class="text-sm text-emerald-600 whitespace-pre-line"><%= vue_identifier(@icon, size) %></code>
                          <button
                            type="button"
                            phx-click={JS.dispatch("phx:copy", to: "#vue-#{@icon.icon_id}-#{size}")}
                            class="text-xs text-base-content/70 hover:text-base-content px-2 py-1 rounded hover:bg-base-200"
                          >Copy</button>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              <% end %>

              <!-- Svelte -->
              <%= if @platform_prefs.svelte do %>
                <% {svelte_pkg_name, svelte_pkg_url} = svelte_package(@icon) %>
                <div class="bg-base-100 rounded-lg p-4" id={"svelte-section-#{@icon.icon_id}"} phx-hook="SvelteColor"
                     data-name={@icon.name |> String.downcase() |> String.replace(" ", "_")}
                     data-style={@icon.style_code}
                     data-icon-set={@icon.icon_set_code}
                     data-sizes={Jason.encode!(svelte_identifier_sizes(@icon))}>
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-sm font-medium text-base-content/70 flex items-center gap-1.5">
                      <.platform_icon name="svelte" class="w-4 h-4" />
                      Svelte (<%= if svelte_pkg_url do %><a href={svelte_pkg_url} target="_blank" rel="noreferrer" referrerpolicy="unsafe-url" class="text-primary hover:underline"><%= svelte_pkg_name %></a><% else %><%= svelte_pkg_name %><% end %>)
                    </span>
                    <%= if @icon.icon_set_code == "fluentui" do %>
                      <label class="flex items-center gap-1.5 text-xs text-base-content/70 cursor-pointer">
                        <input type="checkbox" class="svelte-include-color w-3.5 h-3.5 rounded border-base-300" />
                        Include color
                      </label>
                    <% end %>
                  </div>
                  <div class="space-y-1 svelte-code-list">
                    <%= for size <- svelte_identifier_sizes(@icon) do %>
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

              <!-- CSS Class -->
              <%= if @platform_prefs.cssclass do %>
                <% {cssclass_pkg_name, cssclass_pkg_url} = cssclass_package(@icon) %>
                <%= if cssclass_pkg_name do %>
                  <div class="bg-base-100 rounded-lg p-4">
                    <div class="flex items-center justify-between mb-2">
                      <span class="text-sm font-medium text-base-content/70 flex items-center gap-1.5">
                        <.platform_icon name="cssclass" class="w-4 h-4" />
                        CSS Class (<%= if cssclass_pkg_url do %><a href={cssclass_pkg_url} target="_blank" rel="noreferrer" class="text-primary hover:underline"><%= cssclass_pkg_name %></a><% else %><%= cssclass_pkg_name %><% end %>)
                      </span>
                    </div>
                    <div class="space-y-1">
                      <%= for size <- cssclass_identifier_sizes(@icon) do %>
                        <div class="flex items-center justify-between bg-base-200 rounded px-3 py-2 border border-base-300">
                          <code id={"cssclass-#{@icon.icon_id}-#{size}"} class="text-sm text-pink-600"><%= cssclass_identifier(@icon, size) %></code>
                          <button
                            type="button"
                            phx-click={JS.dispatch("phx:copy", to: "#cssclass-#{@icon.icon_id}-#{size}")}
                            class="text-xs text-base-content/70 hover:text-base-content px-2 py-1 rounded hover:bg-base-200"
                          >Copy</button>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              <% end %>

              <!-- HTML Tag -->
              <%= if @platform_prefs.htmltag do %>
                <% {htmltag_pkg_name, htmltag_pkg_url} = htmltag_package(@icon) %>
                <%= if htmltag_pkg_name do %>
                  <div class="bg-base-100 rounded-lg p-4">
                    <div class="flex items-center justify-between mb-2">
                      <span class="text-sm font-medium text-base-content/70 flex items-center gap-1.5">
                        <.platform_icon name="htmltag" class="w-4 h-4" />
                        HTML Tag (<%= if htmltag_pkg_url do %><a href={htmltag_pkg_url} target="_blank" rel="noreferrer" class="text-primary hover:underline"><%= htmltag_pkg_name %></a><% else %><%= htmltag_pkg_name %><% end %>)
                      </span>
                    </div>
                    <div class="space-y-1">
                      <%= for size <- htmltag_identifier_sizes(@icon) do %>
                        <div class="flex items-center justify-between bg-base-200 rounded px-3 py-2 border border-base-300">
                          <code id={"htmltag-#{@icon.icon_id}-#{size}"} class="text-sm text-fuchsia-600"><%= htmltag_identifier(@icon, size) %></code>
                          <button
                            type="button"
                            phx-click={JS.dispatch("phx:copy", to: "#htmltag-#{@icon.icon_id}-#{size}")}
                            class="text-xs text-base-content/70 hover:text-base-content px-2 py-1 rounded hover:bg-base-200"
                          >Copy</button>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
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
          <div class="icon-preview-bg w-16 h-16 mx-auto mb-3 flex items-center justify-center flex-shrink-0 rounded-lg bg-white/80">
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
              <span class={["badge badge-sm", icon_set_color(icon.icon_set_code)]}><%= icon.icon_set_code %></span>
              <span class="badge badge-sm badge-neutral"><%= icon.style_code %></span>
            </div>
            <!-- Sizes with hover-to-copy -->
            <div class="flex flex-wrap justify-center gap-1">
              <%= for size <- icon.sizes do %>
                <div class="relative group/size">
                  <span class="badge badge-sm badge-ghost"><%= size %>px</span>
                  <div class="absolute bottom-full left-1/2 -translate-x-1/2 -mb-0.5 hidden group-hover/size:flex gap-1 bg-base-100 rounded-lg p-1.5 shadow-xl border-2 border-base-content/20 z-10">
                    <%= for platform <- preferred_platforms(@platform_prefs, 2) do %>
                      <button
                        type="button"
                        class={"p-2.5 rounded cursor-pointer hover:bg-base-300 hover:scale-110 active:scale-95 transition-transform #{platform_color(platform)}"}
                        title={"Copy #{platform} identifier for size #{size}"}
                        phx-click={JS.dispatch("phx:copy_text", detail: copy_detail(icon, platform, size))}
                      >
                        <.platform_icon name={to_string(platform)} class="w-5 h-5" />
                      </button>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp icon_list(assigns) do
    assigns = assign(assigns, :display_sizes, if(assigns.selected_sizes == [], do: assigns.available_sizes, else: Enum.sort(assigns.selected_sizes)))
    ~H"""
    <%!-- Mobile: card layout --%>
    <div class="md:hidden space-y-3">
      <%= for icon <- @icons do %>
        <div
          phx-click="select_icon"
          phx-value-id={icon.icon_id}
          class="bg-base-200 rounded-lg p-3 cursor-pointer hover:bg-base-300 transition-colors border border-base-300"
        >
          <div class="flex items-center gap-2">
            <span class="icon-card-preview icon-preview-bg inline-svg-icon inline-flex items-center justify-center rounded bg-white/80 p-1.5 flex-shrink-0"
                  style={"width: #{trunc(@icon_list_size * 1.5)}px; height: #{trunc(@icon_list_size * 1.5)}px;"}
                  data-svg-url={Icon.svg_url(icon, default_size(icon.sizes))}></span>
            <div class="flex-1 min-w-0">
              <div class="font-medium text-base-content truncate mb-1"><%= icon.name %></div>
              <div class="flex flex-wrap gap-1 mt-0.5">
                <span class={["badge badge-sm", icon_set_color(icon.icon_set_code)]}><%= icon.icon_set_code %></span>
                <span class="badge badge-sm badge-neutral capitalize"><%= icon.style_code %></span>
              </div>
            </div>
          </div>
          <div class="flex flex-wrap gap-1 mt-1">
            <%= for size <- icon.sizes do %>
              <span class="badge badge-sm badge-ghost"><%= size %>px</span>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>

    <%!-- Desktop: table layout --%>
    <div class="hidden md:block bg-base-200 rounded-lg border border-base-300">
      <div>
        <table class="w-full text-sm">
          <thead class="bg-base-200 border-b-2 border-base-300 sticky-table-header">
            <tr>
              <th class="w-16 px-4 py-4 text-left font-semibold text-base-content text-base sticky bg-base-200 z-20" style="top: var(--sticky-header-height, 0px)">Icon</th>
              <th class="px-4 py-4 text-left font-semibold text-base-content text-base sticky bg-base-200 z-20" style="top: var(--sticky-header-height, 0px)">Set</th>
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
                  <span class="icon-list-preview icon-preview-bg inline-svg-icon inline-flex items-center justify-center rounded bg-white/80 p-1"
                        style={"width: #{@icon_list_size}px; height: #{@icon_list_size}px;"}
                        data-svg-url={Icon.svg_url(icon, default_size(icon.sizes))}></span>
                </td>
                <td class="px-4 py-3">
                  <span class={["badge badge-sm", icon_set_color(icon.icon_set_code)]}><%= icon.icon_set_code %></span>
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
                              phx-click={JS.dispatch("phx:copy_text", detail: copy_detail(icon, platform, size))}
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
    [:ios, :android, :react, :vue, :svelte, :cssclass, :htmltag, :filename]
    |> Enum.filter(&Map.get(prefs, &1, false))
    |> Enum.take(count)
  end

  defp platform_color(:ios), do: "text-primary"
  defp platform_color(:android), do: "text-success"
  defp platform_color(:react), do: "text-cyan-600"
  defp platform_color(:vue), do: "text-emerald-600"
  defp platform_color(:svelte), do: "text-orange-600"
  defp platform_color(:cssclass), do: "text-pink-600"
  defp platform_color(:htmltag), do: "text-fuchsia-600"
  defp platform_color(:filename), do: "text-base-content/70"
  defp platform_color(_), do: "text-base-content/70"

  defp get_platform_id(icon, :ios), do: get_ios_id(icon)
  defp get_platform_id(icon, :android), do: get_android_id(icon)
  defp get_platform_id(icon, :react), do: react_identifier(icon, default_size(icon.sizes))
  defp get_platform_id(icon, :vue), do: vue_identifier(icon, default_size(icon.sizes))
  defp get_platform_id(icon, :svelte), do: svelte_identifier(icon, default_size(icon.sizes))
  defp get_platform_id(icon, :cssclass), do: cssclass_identifier(icon, default_size(icon.sizes))
  defp get_platform_id(icon, :htmltag), do: htmltag_identifier(icon, default_size(icon.sizes))
  defp get_platform_id(icon, :filename), do: Icon.svg_filename(icon, default_size(icon.sizes))
  defp get_platform_id(_, _), do: "N/A"

  # Get platform identifier for a specific size
  defp copy_detail(icon, :filename, size) do
    filename = Icon.svg_filename(icon, size) || ""
    %{
      text: filename,
      platform: "filename",
      filename: filename,
      name: icon.name,
      style: icon.style_code,
      size: size,
      icon_id: icon.icon_id
    }
  end

  defp copy_detail(icon, platform, size) do
    %{
      text: get_platform_id_for_size(icon, platform, size),
      platform: to_string(platform),
      size: size,
      icon_id: icon.icon_id
    }
  end

  defp get_platform_id_for_size(icon, :ios, size) do
    Map.get(icon.ios_identifiers, to_string(size), "N/A")
  end
  defp get_platform_id_for_size(icon, :android, size) do
    Map.get(icon.android_identifiers, to_string(size), "N/A")
  end
  defp get_platform_id_for_size(icon, :react, size), do: react_identifier(icon, size)
  defp get_platform_id_for_size(icon, :vue, size), do: vue_identifier(icon, size)
  defp get_platform_id_for_size(icon, :svelte, size), do: svelte_identifier(icon, size)
  defp get_platform_id_for_size(icon, :cssclass, size), do: cssclass_identifier(icon, size)
  defp get_platform_id_for_size(icon, :htmltag, size), do: htmltag_identifier(icon, size)
  defp get_platform_id_for_size(icon, :filename, size), do: Icon.svg_filename(icon, size)
  defp get_platform_id_for_size(_, _, _), do: "N/A"

  # React identifiers — icon-set-aware
  defp react_identifier(%{icon_set_code: "fluentui"} = icon, size) do
    name = icon.name |> String.replace(" ", "")
    style = icon.style_code |> String.capitalize()
    "<#{name}#{size}#{style} />"
  end

  defp react_identifier(%{icon_set_code: "lucide"} = icon, _size) do
    name = icon.name |> String.replace(" ", "")
    "import { #{name} } from 'lucide-react'\n<#{name} />"
  end

  defp react_identifier(%{icon_set_code: "tabler"} = icon, _size) do
    name = icon.name |> String.replace(" ", "")
    "import { Icon#{name} } from '@tabler/icons-react'\n<Icon#{name} />"
  end

  defp react_identifier(%{icon_set_code: "heroicons"} = icon, size) do
    name = icon.name |> String.replace(" ", "")
    "import { #{name}Icon } from '@heroicons/react/#{size}/#{icon.style_code}'\n<#{name}Icon />"
  end

  defp react_identifier(%{icon_set_code: "fontawesome"} = icon, _size) do
    fa_name = to_fa_import_name(icon.name)
    pkg = fa_style_package(icon.style_code)
    "import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'\nimport { #{fa_name} } from '#{pkg}'\n<FontAwesomeIcon icon={#{fa_name}} />"
  end

  defp react_identifier(icon, size) do
    name = icon.name |> String.replace(" ", "")
    "<#{name}#{size} />"
  end

  # Svelte identifiers — icon-set-aware
  defp svelte_identifier(%{icon_set_code: "fluentui"} = icon, size) do
    name = icon.name |> String.downcase() |> String.replace(" ", "_")
    ~s(<Icon name="#{name}" size={#{size}} variant="#{icon.style_code}" />)
  end

  defp svelte_identifier(%{icon_set_code: "lucide"} = icon, _size) do
    name = icon.name |> String.replace(" ", "")
    "import { #{name} } from 'lucide-svelte'\n<#{name} />"
  end

  defp svelte_identifier(%{icon_set_code: "tabler"} = icon, _size) do
    name = icon.name |> String.replace(" ", "")
    "import { Icon#{name} } from '@tabler/icons-svelte'\n<Icon#{name} />"
  end

  defp svelte_identifier(%{icon_set_code: "heroicons"} = icon, _size) do
    name = icon.name |> String.replace(" ", "")
    variant = if icon.style_code != "outline", do: " #{icon.style_code}", else: ""
    "import { Icon, #{name} } from 'svelte-hero-icons'\n<Icon src={#{name}}#{variant} />"
  end

  defp svelte_identifier(%{icon_set_code: "fontawesome"} = icon, _size) do
    fa_name = to_fa_import_name(icon.name)
    pkg = fa_style_package(icon.style_code)
    "import Fa from 'svelte-fa'\nimport { #{fa_name} } from '#{pkg}'\n<Fa icon={#{fa_name}} />"
  end

  defp svelte_identifier(icon, size) do
    name = icon.name |> String.downcase() |> String.replace(" ", "_")
    ~s(<Icon name="#{name}" size={#{size}} />)
  end

  # Vue identifiers — icon-set-aware (no FluentUI Vue package)
  defp vue_identifier(%{icon_set_code: "lucide"} = icon, _size) do
    name = icon.name |> String.replace(" ", "")
    "import { #{name} } from 'lucide-vue-next'\n<#{name} />"
  end

  defp vue_identifier(%{icon_set_code: "tabler"} = icon, _size) do
    name = icon.name |> String.replace(" ", "")
    "import { Icon#{name} } from '@tabler/icons-vue'\n<Icon#{name} />"
  end

  defp vue_identifier(%{icon_set_code: "heroicons"} = icon, size) do
    name = icon.name |> String.replace(" ", "")
    "import { #{name}Icon } from '@heroicons/vue/#{size}/#{icon.style_code}'\n<#{name}Icon />"
  end

  defp vue_identifier(%{icon_set_code: "fontawesome"} = icon, _size) do
    fa_name = to_fa_import_name(icon.name)
    pkg = fa_style_package(icon.style_code)
    "import { FontAwesomeIcon } from '@fortawesome/vue-fontawesome'\nimport { #{fa_name} } from '#{pkg}'\n<font-awesome-icon :icon=\"#{fa_name}\" />"
  end

  defp vue_identifier(icon, _size) do
    name = icon.name |> String.replace(" ", "")
    "<#{name} />"
  end

  # CSS class identifiers — raw class string only, for use in config/JSON/menu definitions
  defp cssclass_identifier(%{icon_set_code: "fontawesome"} = icon, _size) do
    kebab = icon.name |> String.downcase() |> String.replace(" ", "-")
    style_prefix =
      case icon.style_code do
        "solid" -> "fa-solid"
        "regular" -> "fa-regular"
        "brands" -> "fa-brands"
        _ -> "fa-solid"
      end
    "#{style_prefix} fa-#{kebab}"
  end

  defp cssclass_identifier(%{icon_set_code: "tabler"} = icon, _size) do
    kebab = icon.name |> String.downcase() |> String.replace(" ", "-")
    suffix = if icon.style_code == "filled", do: "-filled", else: ""
    "ti ti-#{kebab}#{suffix}"
  end

  defp cssclass_identifier(_icon, _size), do: nil

  # HTML tag identifiers — full <i> element, ready to paste into HTML/JSX
  defp htmltag_identifier(icon, size) do
    case cssclass_identifier(icon, size) do
      nil -> nil
      class -> ~s(<i class="#{class}"></i>)
    end
  end

  # Package name helpers
  defp react_package(%{icon_set_code: "fluentui"}), do: {"@fluentui/react-icons", "https://www.npmjs.com/package/@fluentui/react-icons"}
  defp react_package(%{icon_set_code: "lucide"}), do: {"lucide-react", "https://www.npmjs.com/package/lucide-react"}
  defp react_package(%{icon_set_code: "tabler"}), do: {"@tabler/icons-react", "https://www.npmjs.com/package/@tabler/icons-react"}
  defp react_package(%{icon_set_code: "heroicons"}), do: {"@heroicons/react", "https://www.npmjs.com/package/@heroicons/react"}
  defp react_package(%{icon_set_code: "fontawesome"}), do: {"@fortawesome/react-fontawesome", "https://www.npmjs.com/package/@fortawesome/react-fontawesome"}
  defp react_package(_), do: {nil, nil}

  defp svelte_package(%{icon_set_code: "fluentui"}), do: {"svelte-fluentui", "https://svelte-fluentui.keenmate.dev"}
  defp svelte_package(%{icon_set_code: "lucide"}), do: {"lucide-svelte", "https://lucide.dev"}
  defp svelte_package(%{icon_set_code: "tabler"}), do: {"@tabler/icons-svelte", "https://tabler.io/icons"}
  defp svelte_package(%{icon_set_code: "heroicons"}), do: {"svelte-hero-icons", "https://www.npmjs.com/package/svelte-hero-icons"}
  defp svelte_package(%{icon_set_code: "fontawesome"}), do: {"svelte-fa", "https://www.npmjs.com/package/svelte-fa"}
  defp svelte_package(_), do: {nil, nil}

  # Vue: no official FluentUI Vue package
  defp vue_package(%{icon_set_code: "fluentui"}), do: {nil, nil}
  defp vue_package(%{icon_set_code: "lucide"}), do: {"lucide-vue-next", "https://www.npmjs.com/package/lucide-vue-next"}
  defp vue_package(%{icon_set_code: "tabler"}), do: {"@tabler/icons-vue", "https://www.npmjs.com/package/@tabler/icons-vue"}
  defp vue_package(%{icon_set_code: "heroicons"}), do: {"@heroicons/vue", "https://www.npmjs.com/package/@heroicons/vue"}
  defp vue_package(%{icon_set_code: "fontawesome"}), do: {"@fortawesome/vue-fontawesome", "https://www.npmjs.com/package/@fortawesome/vue-fontawesome"}
  defp vue_package(_), do: {nil, nil}

  # CSS class packages — only icon sets with web font / CSS class APIs
  defp cssclass_package(%{icon_set_code: "fontawesome"}), do: {"@fortawesome/fontawesome-free", "https://www.npmjs.com/package/@fortawesome/fontawesome-free"}
  defp cssclass_package(%{icon_set_code: "tabler"}), do: {"@tabler/icons-webfont", "https://www.npmjs.com/package/@tabler/icons-webfont"}
  defp cssclass_package(_), do: {nil, nil}

  # HTML tag follows same availability as CSS class
  defp htmltag_package(icon), do: cssclass_package(icon)

  # For React: FluentUI and Heroicons vary by size, others show single row
  defp react_identifier_sizes(%{icon_set_code: "fluentui"} = icon), do: icon.sizes
  defp react_identifier_sizes(%{icon_set_code: "heroicons"} = icon), do: icon.sizes
  defp react_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]

  # For Vue: Heroicons varies by size (import path includes size/style), others single row
  defp vue_identifier_sizes(%{icon_set_code: "heroicons"} = icon), do: icon.sizes
  defp vue_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]

  # For Svelte: only FluentUI varies by size
  defp svelte_identifier_sizes(%{icon_set_code: "fluentui"} = icon), do: icon.sizes
  defp svelte_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]

  # CSS classes don't vary by size — single row
  defp cssclass_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]
  defp htmltag_identifier_sizes(icon), do: [List.first(icon.sizes) || 24]

  # Color method display helpers
  defp color_method_label("fill"), do: "CSS: fill / color"
  defp color_method_label("stroke"), do: "CSS: stroke / color"
  defp color_method_label("multicolor"), do: "Multicolor"
  defp color_method_label(_), do: ""

  defp color_method_class("fill"), do: "bg-blue-100 text-blue-700"
  defp color_method_class("stroke"), do: "bg-emerald-100 text-emerald-700"
  defp color_method_class("multicolor"), do: "bg-amber-100 text-amber-700"
  defp color_method_class(_), do: "bg-base-200 text-base-content/70"

  # Icon set badge colors
  defp icon_set_color("fluentui"), do: "bg-blue-600 text-white"
  defp icon_set_color("heroicons"), do: "bg-violet-600 text-white"
  defp icon_set_color("lucide"), do: "bg-orange-500 text-white"
  defp icon_set_color("tabler"), do: "bg-cyan-600 text-white"
  defp icon_set_color("fontawesome"), do: "bg-yellow-500 text-black"
  defp icon_set_color(_), do: "bg-base-300 text-base-content"

  # Font Awesome helpers: "Arrow Right" -> "faArrowRight"
  defp to_fa_import_name(display_name) do
    pascal = display_name |> String.replace(" ", "")
    "fa#{pascal}"
  end

  # Font Awesome style -> npm package
  defp fa_style_package("solid"), do: "@fortawesome/free-solid-svg-icons"
  defp fa_style_package("regular"), do: "@fortawesome/free-regular-svg-icons"
  defp fa_style_package("brands"), do: "@fortawesome/free-brands-svg-icons"
  defp fa_style_package(_), do: "@fortawesome/free-solid-svg-icons"

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

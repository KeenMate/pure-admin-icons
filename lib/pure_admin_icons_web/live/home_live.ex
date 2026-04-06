defmodule PureAdminIconsWeb.HomeLive do
  use PureAdminIconsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Home")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Nav --%>
    <div class="flex items-center justify-between px-4 sm:px-6 lg:px-8 py-3">
      <Layouts.logo />
      <div class="flex items-center gap-2">
        <a href="#api-section" class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium text-base-content/80 hover:text-primary hover:bg-base-200 transition-colors">
          <.icon name="hero-code-bracket" class="size-4" /> API
        </a>
        <a href="https://www.npmjs.com/package/@keenmate/fluentui-icons-mcp" target="_blank" rel="noreferrer" class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium text-base-content/80 hover:text-primary hover:bg-base-200 transition-colors">
          <.icon name="hero-puzzle-piece" class="size-4" /> MCP
        </a>
        <a href="/llms.txt" class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium text-base-content/80 hover:text-primary hover:bg-base-200 transition-colors">
          <.icon name="hero-light-bulb" class="size-4" /> LLMs
        </a>
        <a href="https://keenmate.com" target="_blank" rel="noreferrer" class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium text-base-content/80 hover:text-primary hover:bg-base-200 transition-colors">
          <.icon name="hero-building-office-2" class="size-4" /> Keenmate
        </a>
      </div>
    </div>

    <%!-- Hero --%>
    <div class="hero-gradient py-10 px-4 border-b border-base-300">
      <div class="max-w-5xl mx-auto text-center">
        <p class="text-base-content/70 text-lg">
          Search <span class="font-semibold text-primary">7000+</span> icons from
          <span class="font-semibold text-primary">4</span> icon sets
        </p>
        <p class="text-sm text-base-content/50 mt-1">
          Using Claude? Try our
          <a href="https://www.npmjs.com/package/@keenmate/fluentui-icons-mcp" target="_blank" rel="noreferrer" class="text-primary hover:underline">MCP server</a>
          to search icons directly from Claude Desktop or Claude Code.
        </p>

        <div class="mt-6 max-w-2xl mx-auto">
          <input
            type="text"
            placeholder="Search icons (e.g., 'pen', 'calendar', 'add')..."
            class="input input-bordered w-full search-glow"
            disabled
          />
        </div>
      </div>
    </div>

    <%!-- Content --%>
    <main class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl">
        <div class="text-center py-20">
          <h2 class="text-2xl font-bold text-base-content">Icon search coming soon</h2>
          <p class="text-base-content/60 mt-2">Business logic will be ported from fluentui-icons.</p>
        </div>
      </div>
    </main>

    <Layouts.flash_group flash={@flash} />
    """
  end
end

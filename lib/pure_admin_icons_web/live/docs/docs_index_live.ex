defmodule PureAdminIconsWeb.Docs.DocsIndexLive do
  use PureAdminIconsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Documentation")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-10">
      <div class="mb-8 flex items-center justify-between">
        <Layouts.logo class="text-2xl" />
        <a
          href="/"
          class="inline-flex items-center gap-1.5 text-sm text-base-content/60 hover:text-primary transition-colors"
        >
          <.icon name="hero-arrow-left" class="size-4" /> Back to search
        </a>
      </div>

      <div class="rounded-box bg-base-200 overflow-hidden border border-base-300 p-8">
        <h1 class="text-3xl font-bold mb-2">Documentation</h1>
        <p class="text-base-content/60 mb-8">
          Guides for searching icons, using the API, and integrating with AI tools.
        </p>

        <div class="grid gap-4 sm:grid-cols-2">
          <.doc_card
            href="/docs/api"
            icon="hero-code-bracket"
            title="API Reference"
            description="REST endpoints for searching icons. Response formats, filtering, pagination, and usage examples."
          />

          <.doc_card
            href="/docs/mcp"
            icon="hero-puzzle-piece"
            title="MCP Server"
            description="Use the MCP server to search icons directly from Claude Desktop or Claude Code. Install, configure, and use."
          />

          <.doc_card
            href="/docs/llms"
            icon="hero-light-bulb"
            title="LLM Integration"
            description="Token-efficient text format, llms.txt, ai-plugin.json. Best practices for AI-powered icon search."
          />
        </div>
      </div>

      <footer class="text-center text-base-content/50 text-xs py-8">
        icons.pureadmin.io &middot; by
        <a href="https://keenmate.com" class="hover:text-primary">KeenMate</a>
      </footer>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true

  defp doc_card(assigns) do
    ~H"""
    <a
      href={@href}
      class="group block rounded-xl border border-base-300/50 bg-base-100/50 p-6 hover:border-primary/30 hover:bg-base-100 transition-all"
    >
      <div class="flex items-center gap-3 mb-2">
        <span class={"#{@icon} size-5 text-primary/70 group-hover:text-primary transition-colors"}>
        </span>
        <h2 class="text-lg font-semibold group-hover:text-primary transition-colors">{@title}</h2>
      </div>
      <p class="text-sm text-base-content/60">{@description}</p>
    </a>
    """
  end
end

defmodule PureAdminIconsWeb.Docs.McpDocsLive do
  use PureAdminIconsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "MCP Server")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-10">
      <div class="mb-8 flex items-center justify-between">
        <Layouts.logo class="text-2xl" />
        <a
          href="/docs"
          class="inline-flex items-center gap-1.5 text-sm text-base-content/60 hover:text-primary transition-colors"
        >
          <.icon name="hero-arrow-left" class="size-4" /> Back to docs
        </a>
      </div>

      <div class="rounded-box bg-base-200 overflow-hidden border border-base-300 p-8">
        <h1 class="text-3xl font-bold mb-2">MCP Server</h1>
        <p class="text-base-content/60 mb-8">
          Search icons directly from Claude Desktop or Claude Code using the MCP (Model Context Protocol) server.
        </p>

        <div class="space-y-8">
          <div>
            <h2 class="text-xl font-bold border-b border-base-300/50 pb-2 mb-4">Installation</h2>
            <p class="text-base-content/70 text-sm mb-4">
              The MCP server is published as an npm package. No local installation needed — npx runs it on demand.
            </p>
            <p class="text-base-content/70 text-sm mb-4">
              npm: <a href="https://www.npmjs.com/package/@keenmate/fluentui-icons-mcp" target="_blank" class="text-primary hover:underline">@keenmate/fluentui-icons-mcp</a>
            </p>
          </div>

          <div>
            <h2 class="text-xl font-bold border-b border-base-300/50 pb-2 mb-4">Claude Desktop</h2>
            <p class="text-base-content/70 text-sm mb-3">
              Add this to your Claude Desktop configuration file:
            </p>
            <pre class="rounded-lg px-4 py-3 text-sm overflow-x-auto !bg-transparent border border-base-300/30"><code>{~s|{\n  "mcpServers": {\n    "fluentui-icons": {\n      "command": "npx",\n      "args": ["-y", "@keenmate/fluentui-icons-mcp"]\n    }\n  }\n}|}</code></pre>
          </div>

          <div>
            <h2 class="text-xl font-bold border-b border-base-300/50 pb-2 mb-4">Claude Code</h2>
            <p class="text-base-content/70 text-sm mb-3">
              Add the MCP server to your Claude Code settings:
            </p>
            <pre class="rounded-lg px-4 py-3 text-sm overflow-x-auto !bg-transparent border border-base-300/30"><code>claude mcp add fluentui-icons -- npx -y @keenmate/fluentui-icons-mcp</code></pre>
          </div>

          <div>
            <h2 class="text-xl font-bold border-b border-base-300/50 pb-2 mb-4">Available Tools</h2>
            <div class="space-y-4 text-sm">
              <div class="border-b border-base-300/30 pb-4">
                <div class="flex items-center gap-3 mb-2">
                  <code class="text-primary font-mono">search_icons</code>
                </div>
                <p class="text-base-content/70">Search icons by name. Filter by style and size. Returns icon names, styles, sizes, and SVG URLs.</p>
              </div>
              <div class="border-b border-base-300/30 pb-4">
                <div class="flex items-center gap-3 mb-2">
                  <code class="text-primary font-mono">get_icon_svg</code>
                </div>
                <p class="text-base-content/70">Fetch the raw SVG content of a specific icon. Useful for embedding icons directly.</p>
              </div>
            </div>
          </div>

          <div>
            <h2 class="text-xl font-bold border-b border-base-300/50 pb-2 mb-4">Usage Example</h2>
            <p class="text-base-content/70 text-sm mb-3">
              Once configured, ask Claude:
            </p>
            <div class="space-y-2 text-sm text-base-content/70">
              <p class="italic">"Find me a calendar icon in regular style, 24px"</p>
              <p class="italic">"Search for arrow icons available in the filled style"</p>
              <p class="italic">"Get the SVG for the Add icon"</p>
            </div>
          </div>
        </div>
      </div>

      <footer class="text-center text-base-content/50 text-xs py-8">
        icons.pureadmin.io &middot; by
        <a href="https://keenmate.com" class="hover:text-primary">KeenMate</a>
      </footer>
    </div>
    """
  end
end

defmodule PureAdminIconsWeb.Docs.ApiDocsLive do
  use PureAdminIconsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "API")}
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
        <h1 class="text-3xl font-bold mb-2">API</h1>
        <p class="text-base-content/60 mb-8">
          Search icons programmatically. All endpoints return JSON. No authentication required.
        </p>

        <%!-- Search --%>
        <div class="space-y-8">
          <h2 class="text-xl font-bold border-b border-base-300/50 pb-2">Search</h2>

          <.endpoint
            method="GET"
            path="/api/icons/search"
            description="Search icons by name across all icon sets. Supports full-text search, trigram similarity, and synonym matching."
            params={[
              {"q", "Search query (required)"},
              {"set", "Filter by icon set: fluentui, lucide, tabler, heroicons"},
              {"size", "Filter by size: 16, 20, 24, 28, 32, 48"},
              {"style", "Filter by style: regular, filled, outline, solid, color, light"},
              {"limit", "Max results (default: 50, max: 100)"},
              {"format", "Response format: json (default), compact, text"}
            ]}
            example_url="/api/icons/search?q=calendar&set=fluentui&size=24"
          />
        </div>

        <%!-- Response formats --%>
        <div class="space-y-8 mt-10">
          <h2 class="text-xl font-bold border-b border-base-300/50 pb-2">Response Formats</h2>

          <div class="space-y-4 text-sm text-base-content/70">
            <div class="flex gap-2">
              <code class="text-primary/80 font-mono">json</code>
              <span class="text-base-content/50">&mdash;</span>
              <span>Full response with all metadata, platform identifiers, sizes, filenames</span>
            </div>
            <div class="flex gap-2">
              <code class="text-primary/80 font-mono">compact</code>
              <span class="text-base-content/50">&mdash;</span>
              <span>Minimal JSON: name, style, url</span>
            </div>
            <div class="flex gap-2">
              <code class="text-primary/80 font-mono">text</code>
              <span class="text-base-content/50">&mdash;</span>
              <span>Plain text, one icon per line (most token-efficient for AI/LLMs)</span>
            </div>
          </div>
        </div>

        <%!-- Other endpoints --%>
        <div class="space-y-8 mt-10">
          <h2 class="text-xl font-bold border-b border-base-300/50 pb-2">Other Endpoints</h2>

          <.endpoint
            method="GET"
            path="/api/health"
            description="Health check. Returns icon count and status."
            params={[]}
            example_url="/api/health"
          />

          <.endpoint
            method="GET"
            path="/icons/:icon_set/:style/:filename"
            description="Serve an icon SVG file. Cached for 1 year with immutable header."
            params={[]}
            example_url="/icons/fluentui/regular/ic_fluent_calendar_24_regular.svg"
            response_type="image/svg+xml"
          />
        </div>

        <%!-- AI/LLM integration --%>
        <div class="border-t border-base-300/50 mt-10 pt-8">
          <h2 class="text-xl font-bold mb-4">AI / LLM Integration</h2>

          <p class="text-base-content/70 text-sm mb-4">
            For AI assistants and LLMs, use the <code class="text-xs font-mono text-primary/80">text</code> format for maximum token efficiency.
            We also provide an MCP server for direct integration with Claude Desktop and Claude Code.
          </p>

          <div class="space-y-6">
            <div>
              <h3 class="text-sm font-semibold uppercase tracking-wider text-base-content/60 mb-2">
                MCP Server (Claude Desktop / Claude Code)
              </h3>
              <.code_block code={~s|{\n  "mcpServers": {\n    "fluentui-icons": {\n      "command": "npx",\n      "args": ["-y", "@keenmate/fluentui-icons-mcp"]\n    }\n  }\n}|} lang="json" />
            </div>

            <div>
              <h3 class="text-sm font-semibold uppercase tracking-wider text-base-content/60 mb-2">
                LLM-friendly endpoint
              </h3>
              <.code_block code="curl 'https://icons.pureadmin.io/api/icons/search?q=calendar&format=text'" />
            </div>

            <div>
              <h3 class="text-sm font-semibold uppercase tracking-wider text-base-content/60 mb-2">
                Machine-readable docs
              </h3>
              <p class="text-base-content/70 text-sm">
                <a href="/llms.txt" class="text-primary hover:underline">/llms.txt</a> &middot;
                <a href="/.well-known/ai-plugin.json" class="text-primary hover:underline">/.well-known/ai-plugin.json</a>
              </p>
            </div>
          </div>
        </div>

        <%!-- Usage examples --%>
        <div class="border-t border-base-300/50 mt-10 pt-8">
          <h2 class="text-xl font-bold mb-4">Usage Examples</h2>

          <div class="space-y-6">
            <div>
              <h3 class="text-sm font-semibold uppercase tracking-wider text-base-content/60 mb-2">
                Search icons (cURL)
              </h3>
              <.code_block code="curl 'https://icons.pureadmin.io/api/icons/search?q=pen&size=24&limit=5'" />
            </div>

            <div>
              <h3 class="text-sm font-semibold uppercase tracking-wider text-base-content/60 mb-2">
                Search icons (JavaScript)
              </h3>
              <.code_block code={~s|const res = await fetch('https://icons.pureadmin.io/api/icons/search?q=calendar&format=compact');\nconst { icons } = await res.json();\nconsole.log(icons.map(i => i.name));|} lang="javascript" />
            </div>

            <div>
              <h3 class="text-sm font-semibold uppercase tracking-wider text-base-content/60 mb-2">
                Filter by icon set
              </h3>
              <.code_block code="curl 'https://icons.pureadmin.io/api/icons/search?q=arrow&set=heroicons&set=lucide'" />
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

  attr :method, :string, required: true
  attr :path, :string, required: true
  attr :description, :string, required: true
  attr :params, :list, default: []
  attr :example_url, :string, default: nil
  attr :response_type, :string, default: "application/json"
  attr :note, :string, default: nil

  defp endpoint(assigns) do
    ~H"""
    <div class="border-b border-base-300/30 pb-6 last:border-0">
      <div class="flex items-center gap-3 mb-2">
        <span class={"px-2 py-0.5 rounded text-xs font-bold #{if @method == "GET", do: "bg-success/20 text-success", else: "bg-warning/20 text-warning"}"}>
          {@method}
        </span>
        <code class="text-sm font-mono text-primary">{@path}</code>
      </div>
      <p class="text-base-content/70 text-sm mb-3">{@description}</p>

      <%= if @note do %>
        <p class="text-xs text-base-content/50 mb-3">{@note}</p>
      <% end %>

      <%= if Enum.any?(@params) do %>
        <div class="mb-3">
          <span class="text-xs font-semibold uppercase tracking-wider text-base-content/50">
            Parameters
          </span>
          <div class="mt-1 space-y-1">
            <%= for {name, desc} <- @params do %>
              <div class="flex gap-2 text-sm">
                <code class="text-primary/80 font-mono">{name}</code>
                <span class="text-base-content/50">&mdash;</span>
                <span class="text-base-content/60">{desc}</span>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if @example_url do %>
        <div class="flex items-center gap-2">
          <span class="text-xs text-base-content/40">Try:</span>
          <a
            href={@example_url}
            target="_blank"
            class="text-xs font-mono text-primary/70 hover:text-primary"
          >
            {@example_url}
          </a>
        </div>
      <% end %>

      <%= if @response_type != "application/json" do %>
        <span class="text-xs text-base-content/40">Response: {@response_type}</span>
      <% end %>
    </div>
    """
  end

  attr :code, :string, required: true
  attr :lang, :string, default: "bash"

  defp code_block(assigns) do
    ~H"""
    <pre class="rounded-lg px-4 py-3 text-sm overflow-x-auto !bg-transparent border border-base-300/30"><code class={"language-#{@lang} hljs"}><%= @code %></code></pre>
    """
  end
end

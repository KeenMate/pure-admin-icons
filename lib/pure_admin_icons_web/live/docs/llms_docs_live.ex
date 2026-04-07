defmodule PureAdminIconsWeb.Docs.LlmsDocsLive do
  use PureAdminIconsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "LLM Integration")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.site_nav />
    <div class="max-w-4xl mx-auto px-4 py-10">
      <div class="rounded-box bg-base-200 overflow-hidden border border-base-300 p-8">
        <h1 class="text-3xl font-bold mb-2">LLM Integration</h1>
        <p class="text-base-content/60 mb-8">
          Best practices for using icons.pureadmin.io with AI assistants and large language models.
        </p>

        <div class="space-y-8">
          <div>
            <h2 class="text-xl font-bold border-b border-base-300/50 pb-2 mb-4">Text Format</h2>
            <p class="text-base-content/70 text-sm mb-3">
              Use <code class="text-xs font-mono text-primary/80">format=text</code> for the most token-efficient response. Returns one icon per line, plain text.
            </p>
            <pre class="rounded-lg px-4 py-3 text-sm overflow-x-auto !bg-transparent border border-base-300/30"><code>curl 'https://icons.pureadmin.io/api/icons/search?q=calendar&format=text'</code></pre>
          </div>

          <div>
            <h2 class="text-xl font-bold border-b border-base-300/50 pb-2 mb-4">Machine-Readable Docs</h2>
            <div class="space-y-4 text-sm">
              <div class="flex gap-3">
                <a href="/llms.txt" class="text-primary hover:underline font-mono">/llms.txt</a>
                <span class="text-base-content/50">&mdash;</span>
                <span class="text-base-content/70">Plain text documentation for LLMs. Describes the API, search syntax, and available icon sets.</span>
              </div>
              <div class="flex gap-3">
                <a href="/.well-known/ai-plugin.json" class="text-primary hover:underline font-mono">/.well-known/ai-plugin.json</a>
                <span class="text-base-content/50">&mdash;</span>
                <span class="text-base-content/70">OpenAI plugin manifest. Allows ChatGPT and compatible tools to discover the API.</span>
              </div>
            </div>
          </div>

          <div>
            <h2 class="text-xl font-bold border-b border-base-300/50 pb-2 mb-4">MCP Server</h2>
            <p class="text-base-content/70 text-sm">
              For Claude Desktop and Claude Code, use the
              <a href="/docs/mcp" class="text-primary hover:underline">MCP server</a>
              for the best integration experience — it provides structured tool calls instead of raw HTTP.
            </p>
          </div>

          <div>
            <h2 class="text-xl font-bold border-b border-base-300/50 pb-2 mb-4">Tips</h2>
            <ul class="text-sm text-base-content/70 space-y-2">
              <li>Use <code class="text-xs font-mono text-primary/80">format=text</code> to minimize token usage</li>
              <li>Use <code class="text-xs font-mono text-primary/80">limit=5</code> to keep responses small</li>
              <li>Filter by <code class="text-xs font-mono text-primary/80">set</code> if you only need icons from one library</li>
              <li>The <code class="text-xs font-mono text-primary/80">compact</code> format gives structured JSON with minimal fields</li>
            </ul>
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

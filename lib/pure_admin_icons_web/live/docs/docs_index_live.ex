defmodule PureAdminIconsWeb.Docs.DocsIndexLive do
  use PureAdminIconsWeb, :live_view

  import PureAdminIcons.Translations, only: [t: 1]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, t("docsIndex.headers.pageTitle"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.site_nav />
    <div class="max-w-4xl mx-auto px-4 py-10">
      <div class="rounded-box bg-base-200 overflow-hidden border border-base-300 p-8">
        <h1 class="text-3xl font-bold mb-2">{t("docsIndex.headers.pageTitle")}</h1>
        <p class="text-base-content/60 mb-8">
          {t("docsIndex.messages.intro")}
        </p>

        <div class="grid gap-4 sm:grid-cols-2">
          <.doc_card
            href="/docs/api"
            icon="hero-code-bracket"
            title={t("docsIndex.cards.apiTitle")}
            description={t("docsIndex.cards.apiDescription")}
          />

          <.doc_card
            href="/docs/icon-sets"
            icon="hero-squares-2x2"
            title={t("docsIndex.cards.iconSetsTitle")}
            description={t("docsIndex.cards.iconSetsDescription")}
          />

          <.doc_card
            href="/docs/mcp"
            icon="hero-puzzle-piece"
            title={t("docsIndex.cards.mcpTitle")}
            description={t("docsIndex.cards.mcpDescription")}
          />

          <.doc_card
            href="/docs/llms"
            icon="hero-light-bulb"
            title={t("docsIndex.cards.llmsTitle")}
            description={t("docsIndex.cards.llmsDescription")}
          />
        </div>
      </div>

      <footer class="text-center text-base-content/50 text-xs py-8">
        icons.pureadmin.io &middot; {t("common.labels.by")}
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

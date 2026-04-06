defmodule PureAdminIconsWeb.Router do
  use PureAdminIconsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PureAdminIconsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Icon SVG files — minimal pipeline, no session/CSRF overhead
  scope "/icons", PureAdminIconsWeb do
    get "/:icon_set/:style/:filename", IconFileController, :show
    get "/:style/:filename", IconFileController, :show
  end

  scope "/", PureAdminIconsWeb do
    pipe_through :browser

    live "/", IconSearchLive
    live "/docs", Docs.DocsIndexLive
    live "/docs/api", Docs.ApiDocsLive
    live "/docs/mcp", Docs.McpDocsLive
    live "/docs/llms", Docs.LlmsDocsLive
    live "/sync/discrepancies", SyncDiscrepanciesLive
  end

  scope "/api", PureAdminIconsWeb.API do
    pipe_through :api

    get "/icons/search", IconController, :search
    get "/health", HealthController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", PureAdminIconsWeb do
  #   pipe_through :api
  # end
end

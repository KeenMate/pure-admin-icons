defmodule PureAdminIconsWeb.Layouts do
  @moduledoc """
  Layouts and shared UI components for icons.pureadmin.io.
  Mirrors the structure of pureadmin.io's layouts.
  """
  use PureAdminIconsWeb, :html

  embed_templates "layouts/*"

  attr :class, :string, default: "text-lg"

  def logo(assigns) do
    ~H"""
    <a href="/" class="font-bold hover:opacity-80 transition-opacity">
      <span class={@class}>icons.</span><span class={["text-primary", @class]}>pure</span><span class={@class}>admin.io</span>
    </a>
    """
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <.logo />
      </div>
      <div class="flex-none">
        <ul class="flex flex-column px-1 space-x-4 items-center">
          <li>
            <a href="/docs" class="btn btn-ghost">
              <.icon name="hero-book-open" class="size-4" /> Docs
            </a>
          </li>
          <li>
            <a href="/docs/api" class="btn btn-ghost">
              <.icon name="hero-code-bracket" class="size-4" /> API
            </a>
          </li>
          <li>
            <a href="https://keenmate.com" target="_blank" rel="noreferrer" class="btn btn-ghost">
              <.icon name="hero-building-office-2" class="size-4" /> Keenmate
            </a>
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <div
      class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full"
      data-theme-toggle
    >
      <div class="theme-toggle-pill absolute w-1/5 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 transition-[left]" />

      <button class="flex p-2 cursor-pointer w-1/5 z-10" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="auto" title="Auto (time-based)">
        <.icon name="hero-clock-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button class="flex p-2 cursor-pointer w-1/5 z-10" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="morning" title="Morning">
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button class="flex p-2 cursor-pointer w-1/5 z-10" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="day" title="Day">
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button class="flex p-2 cursor-pointer w-1/5 z-10" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="evening" title="Evening">
        <.icon name="hero-cloud-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button class="flex p-2 cursor-pointer w-1/5 z-10" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="night" title="Night">
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end

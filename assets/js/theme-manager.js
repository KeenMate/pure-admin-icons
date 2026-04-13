// Time-of-day theme manager for Pure Theme Park
// Themes: park-morning (5-9), park-day (9-20), park-evening (20-22), park-night (22-5)

const STORAGE_KEY = "theme-override"
const THEME_MAP = { morning: "park-morning", day: "park-day", evening: "park-evening", night: "park-night" }

export function getTimeTheme() {
  const h = new Date().getHours()
  if (h >= 5 && h < 9) return "park-morning"
  if (h >= 9 && h < 20) return "park-day"
  if (h >= 20 && h < 22) return "park-evening"
  return "park-night"
}

function highlightActiveButton() {
  document.querySelectorAll("[data-theme-toggle] .theme-sw-btn").forEach(btn => {
    btn.classList.remove("active")
  })
  const override = localStorage.getItem(STORAGE_KEY)
  const activeValue = override || "auto"
  const activeBtn = document.querySelector(`[data-theme-toggle] [data-phx-theme="${activeValue}"]`)
  if (activeBtn) activeBtn.classList.add("active")
}

export function updateTheme() {
  const override = localStorage.getItem(STORAGE_KEY)
  const theme = override ? THEME_MAP[override] || override : getTimeTheme()
  document.documentElement.setAttribute("data-theme", theme)

  // Signal auto mode to toggle containers
  document.querySelectorAll("[data-theme-toggle]").forEach(toggle => {
    if (override) {
      toggle.removeAttribute("data-auto")
    } else {
      toggle.setAttribute("data-auto", "")
    }
  })

  highlightActiveButton()
}

function handleThemeClick(value) {
  if (value === "auto") {
    localStorage.removeItem(STORAGE_KEY)
  } else {
    localStorage.setItem(STORAGE_KEY, value)
  }
  updateTheme()
}

export function startAutoUpdate() {
  updateTheme()
  setInterval(updateTheme, 60_000)
}

const THEME_NAMES = { auto: "Auto", morning: "Morning", day: "Day", evening: "Evening", night: "Night" }
const THEME_ICONS = {
  auto: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="size-3.5"><path fill-rule="evenodd" d="M10 18a8 8 0 1 0 0-16 8 8 0 0 0 0 16Zm.75-13a.75.75 0 0 0-1.5 0v5c0 .414.336.75.75.75h4a.75.75 0 0 0 0-1.5h-3.25V5Z" clip-rule="evenodd"/></svg>',
  morning: '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-3.5"><path stroke-linecap="round" stroke-linejoin="round" d="M12 3v2.25m6.364.386-1.591 1.591M21 12h-2.25m-.386 6.364-1.591-1.591M12 18.75V21m-4.773-4.227-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0Z"/></svg>',
  day: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="size-3.5"><path d="M10 2a.75.75 0 0 1 .75.75v1.5a.75.75 0 0 1-1.5 0v-1.5A.75.75 0 0 1 10 2ZM10 15a5 5 0 1 0 0-10 5 5 0 0 0 0 10Z"/></svg>',
  evening: '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-3.5"><path stroke-linecap="round" stroke-linejoin="round" d="M21.752 15.002A9.72 9.72 0 0 1 18 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 0 0 3 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 0 0 9.002-5.998Z"/></svg>',
  night: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="size-3.5"><path fill-rule="evenodd" d="M7.455 2.004a.75.75 0 0 1 .26.77 7 7 0 0 0 9.958 7.967.75.75 0 0 1 1.067.853A8.5 8.5 0 1 1 6.647 1.921a.75.75 0 0 1 .808.083Z" clip-rule="evenodd"/></svg>'
}

function updateActiveLabel() {
  const ov = localStorage.getItem(STORAGE_KEY) || "auto"
  const label = document.getElementById("theme-sw-active")
  const iconEl = document.getElementById("theme-sw-active-icon")
  if (label) label.textContent = THEME_NAMES[ov] || "Auto"
  if (iconEl) iconEl.innerHTML = THEME_ICONS[ov] || THEME_ICONS.auto
}

export function initThemeSwitcherDropdown() {
  const trigger = document.getElementById("theme-sw-trigger")
  const panel = document.getElementById("theme-sw-panel")
  if (!trigger || !panel) return

  let cleanupAutoUpdate = null

  const position = () => {
    if (!window.FloatingUIDOM) return
    const { computePosition, offset, flip, shift } = window.FloatingUIDOM
    computePosition(trigger, panel, {
      strategy: "fixed",
      placement: "top-end",
      middleware: [offset(8), flip({ padding: 8 }), shift({ padding: 8 })]
    }).then(({ x, y }) => {
      panel.style.left = `${x}px`
      panel.style.top = `${y}px`
    })
  }

  const open = () => {
    panel.classList.remove("hidden")
    position()
    if (window.FloatingUIDOM && window.FloatingUIDOM.autoUpdate) {
      cleanupAutoUpdate = window.FloatingUIDOM.autoUpdate(trigger, panel, position)
    }
  }

  const close = () => {
    panel.classList.add("hidden")
    if (cleanupAutoUpdate) { cleanupAutoUpdate(); cleanupAutoUpdate = null }
  }

  const toggle = () => panel.classList.contains("hidden") ? open() : close()

  trigger.addEventListener("click", (e) => { e.stopPropagation(); toggle() })

  document.addEventListener("click", (e) => {
    if (!panel.classList.contains("hidden") && !e.target.closest("#theme-switcher")) close()
  })
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && !panel.classList.contains("hidden")) close()
  })

  panel.addEventListener("click", (e) => {
    if (e.target.closest("[data-phx-theme]")) {
      setTimeout(() => { updateActiveLabel(); close() }, 50)
    }
  })

  updateActiveLabel()
}

export function initThemeEvents() {
  // LiveView-dispatched events (from phx-click buttons)
  window.addEventListener("phx:set-theme", (e) => {
    const btn = e.target.closest("[data-phx-theme]")
    if (!btn) return
    handleThemeClick(btn.getAttribute("data-phx-theme"))
  })

  // Direct click on floating switcher (outside LiveView)
  document.addEventListener("click", (e) => {
    const btn = e.target.closest("#theme-switcher [data-phx-theme]")
    if (!btn) return
    handleThemeClick(btn.getAttribute("data-phx-theme"))
  })

  // Recheck theme when user returns to tab (may have crossed a time boundary)
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") updateTheme()
  })
}

// Time-of-day theme manager for Pure Theme Park
// Themes: park-morning (6-11), park-day (11-16), park-evening (16-20), park-night (20-6)

const STORAGE_KEY = "theme-override"
const THEME_MAP = { morning: "park-morning", day: "park-day", evening: "park-evening", night: "park-night" }

export function getTimeTheme() {
  const h = new Date().getHours()
  if (h >= 6 && h < 11) return "park-morning"
  if (h >= 11 && h < 16) return "park-day"
  if (h >= 16 && h < 20) return "park-evening"
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

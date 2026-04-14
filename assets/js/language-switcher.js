// Language switcher dropdown — positioned with Floating UI.
// Mirrors the theme switcher's pattern: click to toggle, outside-click + Esc close,
// autoUpdate keeps it pinned on scroll/resize.

export function initLanguageSwitcherDropdown() {
  const trigger = document.querySelector("[data-language-switcher-trigger]")
  const panel = document.querySelector("[data-language-switcher-panel]")
  if (!trigger || !panel) return

  let cleanupAutoUpdate = null

  const position = () => {
    if (!window.FloatingUIDOM) return
    const { computePosition, offset, flip, shift } = window.FloatingUIDOM
    computePosition(trigger, panel, {
      strategy: "fixed",
      placement: "bottom-end",
      middleware: [offset(6), flip({ padding: 8 }), shift({ padding: 8 })]
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
    if (panel.classList.contains("hidden")) return
    if (e.target.closest("[data-language-switcher]")) return
    close()
  })

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && !panel.classList.contains("hidden")) close()
  })
}

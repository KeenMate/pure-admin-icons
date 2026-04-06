import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}

// Inline SVG loader with lazy loading, caching, and color support
Hooks.IconColorFilter = {
  mounted() {
    this.svgCache = new Map()
    this.loadAllSvgs()
    window.addEventListener('iconColorChanged', () => this.updateAllColors())
  },
  updated() {
    this.updateAllColors()
    this.loadAllSvgs()
  },
  async loadAllSvgs() {
    const icons = this.el.querySelectorAll('.inline-svg-icon')
    if (!this.observer) {
      this.observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            this.loadSvg(entry.target)
            this.observer.unobserve(entry.target)
          }
        })
      }, { rootMargin: '100px' })
    }
    icons.forEach(icon => {
      if (!icon.querySelector('svg')) {
        delete icon.dataset.loaded
        this.observer.observe(icon)
      }
    })
  },
  async loadSvg(container) {
    const color = localStorage.getItem('icon_preview_color') || '#212121'
    const url = container.dataset.svgUrl
    if (!url) return
    try {
      let svgText
      if (this.svgCache.has(url)) {
        svgText = this.svgCache.get(url)
      } else {
        const response = await fetch(url)
        svgText = await response.text()
        this.svgCache.set(url, svgText)
      }
      const coloredSvg = svgText.replace(/fill="#[0-9A-Fa-f]{6}"/g, `fill="${color}"`)
      container.innerHTML = coloredSvg
      const svg = container.querySelector('svg')
      if (svg) {
        svg.style.width = '100%'
        svg.style.height = '100%'
      }
      container.dataset.loaded = 'true'
    } catch (err) {
      console.error('Failed to load SVG:', url, err)
    }
  },
  updateAllColors() {
    const color = localStorage.getItem('icon_preview_color') || '#212121'
    this.el.querySelectorAll('.inline-svg-icon').forEach(icon => {
      icon.querySelectorAll('svg path[fill], svg circle[fill], svg rect[fill]').forEach(el => {
        const currentFill = el.getAttribute('fill')
        if (currentFill && currentFill !== 'none') el.setAttribute('fill', color)
      })
    })
  }
}

// Metrics tracker — exposes pushEvent for JS
Hooks.MetricsTracker = {
  mounted() {
    this.el._pushEvent = (event, params) => {
      this.pushEvent(event, params)
    }
  }
}

// View mode persistence
Hooks.ViewMode = {
  mounted() {
    this.handleEvent("save_view_mode", ({mode}) => {
      localStorage.setItem("icon_view_mode", mode)
      document.documentElement.setAttribute('data-view-mode', mode)
    })
  }
}

// Platform preferences persistence
Hooks.PlatformPrefs = {
  mounted() {
    this.handleEvent("save_platform_prefs", (prefs) => {
      localStorage.setItem("icon_platform_prefs", JSON.stringify(prefs))
    })
  }
}

// ColorPicker hook — modal icon color preview
Hooks.ColorPicker = {
  mounted() {
    this.colorInput = this.el.querySelector('.color-input')
    this.textInput = this.el.querySelector('.color-text')
    this.applySavedColor()
    if (this.colorInput) {
      this.colorInput.addEventListener('input', (e) => {
        if (this.textInput) this.textInput.value = e.target.value
        this.updateSvgColors(e.target.value)
      })
    }
    if (this.textInput) {
      this.textInput.addEventListener('input', (e) => {
        let color = e.target.value
        if (color && !color.startsWith('#')) { color = '#' + color; this.textInput.value = color }
        if (/^#[0-9A-Fa-f]{6}$/.test(color)) {
          if (this.colorInput) this.colorInput.value = color
          this.updateSvgColors(color)
        }
      })
    }
  },
  updated() {
    this.colorInput = this.el.querySelector('.color-input')
    this.textInput = this.el.querySelector('.color-text')
    this.applySavedColor()
  },
  applySavedColor() {
    const savedColor = localStorage.getItem('icon_preview_color') || '#212121'
    requestAnimationFrame(() => {
      if (this.colorInput) this.colorInput.value = savedColor
      if (this.textInput) this.textInput.value = savedColor
    })
  },
  updateSvgColors(color) {
    localStorage.setItem('icon_preview_color', color)
    const svgContainer = document.querySelector('[phx-hook="InlineSvg"]')
    if (svgContainer) {
      svgContainer.dataset.color = color
      svgContainer.querySelectorAll('svg path[fill], svg circle[fill], svg rect[fill]').forEach(el => {
        const currentFill = el.getAttribute('fill')
        if (currentFill && currentFill !== 'none') el.setAttribute('fill', color)
      })
    }
    window.dispatchEvent(new CustomEvent('iconColorChanged'))
  }
}

// InlineSvg hook — loads SVGs in modal preview
Hooks.InlineSvg = {
  mounted() { this.loadSvgs() },
  updated() { this.loadSvgs() },
  async loadSvgs() {
    const color = localStorage.getItem('icon_preview_color') || '#212121'
    const urls = JSON.parse(this.el.dataset.urls || '[]')
    const containers = this.el.querySelectorAll('.svg-container')
    for (let i = 0; i < containers.length && i < urls.length; i++) {
      try {
        const response = await fetch(urls[i])
        const svgText = await response.text()
        const coloredSvg = svgText.replace(/fill="#[0-9A-Fa-f]{6}"/g, `fill="${color}"`)
        containers[i].innerHTML = coloredSvg
        const svg = containers[i].querySelector('svg')
        if (svg) { svg.style.width = `${containers[i].dataset.size}px`; svg.style.height = `${containers[i].dataset.size}px` }
      } catch (err) { console.error('Failed to load SVG:', err) }
    }
  }
}

// SvelteColor hook — toggles color in generated Svelte code
Hooks.SvelteColor = {
  mounted() {
    const checkbox = this.el.querySelector('.svelte-include-color')
    if (!checkbox) return
    const name = this.el.dataset.name, style = this.el.dataset.style
    const sizes = JSON.parse(this.el.dataset.sizes || '[]')
    const savedPref = localStorage.getItem('svelte_include_color') === 'true'
    checkbox.checked = savedPref
    if (savedPref) this.updateCode(name, style, sizes, true)
    checkbox.addEventListener('change', (e) => {
      localStorage.setItem('svelte_include_color', e.target.checked)
      this.updateCode(name, style, sizes, e.target.checked)
    })
  },
  updateCode(name, style, sizes, includeColor) {
    const codeElements = this.el.querySelectorAll('code[data-size]')
    const color = document.querySelector('.color-input')?.value || localStorage.getItem('icon_preview_color') || '#212121'
    codeElements.forEach(code => {
      const size = code.dataset.size
      code.textContent = includeColor
        ? `<Icon name="${name}" size={${size}} variant="${style}" color="custom" customColor="${color}" />`
        : `<Icon name="${name}" size={${size}} variant="${style}" />`
    })
  }
}

// FilenameTemplate hook — custom filename templating
Hooks.FilenameTemplate = {
  mounted() {
    const input = this.el.querySelector("input[type='text']")
    if (!input) return
    const savedTemplate = localStorage.getItem("filename_template") || "{filename}"
    input.value = savedTemplate
    this.renderFilenames()
    input.addEventListener("input", () => {
      localStorage.setItem("filename_template", input.value)
      this.renderFilenames()
    })
  },
  renderFilenames() {
    const input = this.el.querySelector("input[type='text']")
    if (!input) return
    const template = input.value || "{filename}"
    const name = this.el.dataset.name, style = this.el.dataset.style
    const sizes = JSON.parse(this.el.dataset.sizes || '[]')
    const resultsContainer = this.el.querySelector("[id^='filename-results']")
    if (!resultsContainer) return
    const toSnake = s => s.toLowerCase().replace(/\s+/g, '_')
    const toPascal = s => s.split(/\s+/).map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join('')
    const toKebab = s => s.toLowerCase().replace(/\s+/g, '-')
    resultsContainer.innerHTML = sizes.map(size => {
      const origFilename = `ic_fluent_${toSnake(name)}_${size}_${style}.svg`
      const filename = template.replace(/{filename}/g, origFilename).replace(/{name}/g, name)
        .replace(/{name_snake}/g, toSnake(name)).replace(/{name_pascal}/g, toPascal(name))
        .replace(/{name_kebab}/g, toKebab(name)).replace(/{size}/g, size).replace(/{style}/g, style)
      const escaped = filename.replace(/"/g, '&quot;')
      return `<div class="flex items-center justify-between bg-base-200 rounded px-3 py-2 border border-base-300">
        <code class="text-sm text-base-content">${filename}</code>
        <button type="button" class="copy-filename text-xs text-base-content/60 hover:text-base-content px-2 py-1 rounded hover:bg-base-300" data-text="${escaped}">Copy</button>
      </div>`
    }).join("")
    this.el.querySelectorAll(".copy-filename").forEach(btn => {
      btn.onclick = () => navigator.clipboard.writeText(btn.dataset.text).then(() => {
        const orig = btn.textContent; btn.textContent = "Copied!"; setTimeout(() => btn.textContent = orig, 1500)
      })
    })
  }
}

// Copy text handler
window.addEventListener("phx:copy_text", (event) => {
  const { text, icon_id, platform } = event.detail
  if (text) {
    navigator.clipboard.writeText(text).then(() => {
      const button = event.target
      if (button) {
        // Flash green
        const origBg = button.style.backgroundColor
        button.style.backgroundColor = 'oklch(65% 0.17 155 / 0.3)'
        const svg = button.querySelector('svg, span')
        if (svg) { svg.style.color = '#22c55e'; setTimeout(() => svg.style.color = '', 1200) }
        setTimeout(() => button.style.backgroundColor = origBg, 1200)
        // Show brief "Copied!" tooltip
        const tip = document.createElement('div')
        tip.textContent = 'Copied!'
        tip.className = 'fixed z-[100] px-2 py-1 text-xs font-medium rounded bg-success text-success-content shadow-lg pointer-events-none'
        const rect = button.getBoundingClientRect()
        tip.style.left = `${rect.left + rect.width / 2}px`
        tip.style.top = `${rect.top - 30}px`
        tip.style.transform = 'translateX(-50%)'
        document.body.appendChild(tip)
        setTimeout(() => tip.remove(), 1200)
      }
    }).catch(err => console.error('Failed to copy:', err))
  }
})

// Copy handler (modal Copy buttons)
window.addEventListener("phx:copy", (event) => {
  const button = event.detail.dispatcher
  if (button) {
    const container = button.closest('.flex')
    const codeEl = container ? container.querySelector('code') : null
    const hiddenSpan = container ? container.querySelector('span.hidden') : null
    const target = hiddenSpan || codeEl
    if (target) {
      navigator.clipboard.writeText(target.textContent).then(() => {
        const orig = button.textContent
        button.textContent = "Copied!"
        setTimeout(() => button.textContent = orig, 1500)
      }).catch(err => console.error('Failed to copy:', err))
    }
  }
})

// Copy from button (list view)
window.copyFromButton = function(button) {
  const text = button.dataset.copyText
  if (text) {
    navigator.clipboard.writeText(text).then(() => {
      const svg = button.querySelector('svg')
      if (svg) { svg.style.color = '#22c55e'; setTimeout(() => svg.style.color = '', 1000) }
    }).catch(err => console.error('Failed to copy:', err))
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()
window.liveSocket = liveSocket

// Time-of-day theme manager
import { startAutoUpdate, initThemeEvents } from "./theme-manager"
startAutoUpdate()
initThemeEvents()
// Theme transitions disabled — instant switch
// setTimeout(() => document.documentElement.classList.add("theme-transitions"), 100)

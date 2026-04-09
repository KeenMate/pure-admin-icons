import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}

// Inline SVG loader with lazy loading, caching, and color support
Hooks.IconColorFilter = {
  mounted() {
    console.time('[hook] IconColorFilter.mounted')
    this.svgCache = new Map()
    this.applyPreviewBg()
    this.loadAllSvgs()
    console.timeEnd('[hook] IconColorFilter.mounted')
    window.addEventListener('iconColorChanged', () => {
      this.updateAllColors()
      this.applyPreviewBg()
    })
  },
  updated() {
    this.updateAllColors()
    this.applyPreviewBg()
    this.loadAllSvgs()
  },
  applyPreviewBg() {
    let bg = '#ffffff'
    try { bg = JSON.parse(localStorage.getItem('icon_preview_bg') || '"#ffffff"') } catch { bg = localStorage.getItem('icon_preview_bg') || '#ffffff' }
    this.el.querySelectorAll('.icon-preview-bg').forEach(el => {
      el.style.removeProperty('background-image')
      el.style.removeProperty('background-size')
      if (bg === 'checker') {
        el.style.backgroundImage = 'repeating-conic-gradient(#d1d5db 0% 25%, #fff 0% 50%)'
        el.style.backgroundSize = '8px 8px'
        el.style.backgroundColor = ''
      } else {
        el.style.backgroundColor = bg
      }
    })
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
      container.innerHTML = svgText
      const svg = container.querySelector('svg')
      if (svg) {
        svg.style.width = '100%'
        svg.style.height = '100%'
        this.colorizeSvg(svg, color, url)
      }
      container.dataset.loaded = 'true'
    } catch (err) {
      console.error('[IconColorFilter] Failed to load SVG:', url, err)
    }
  },
  // DOM-mutates an SVG to apply the user's color.
  // Updates fill/stroke on the <svg> element AND all child shape elements.
  // This handles icons that put currentColor on the svg parent (Lucide, Heroicons outline)
  // AND icons that put colors directly on paths (FluentUI, Heroicons solid, FA).
  colorizeSvg(svg, color, debugUrl) {
    let touched = 0
    const updateEl = (el) => {
      const currentFill = el.getAttribute('fill')
      if (currentFill && currentFill !== 'none') {
        el.setAttribute('fill', color)
        touched++
      }
      const currentStroke = el.getAttribute('stroke')
      if (currentStroke && currentStroke !== 'none') {
        el.setAttribute('stroke', color)
        touched++
      }
    }
    // Update the <svg> root first (covers icons with fill/stroke on the svg element)
    updateEl(svg)
    // Then walk all child shape elements
    svg.querySelectorAll('path, circle, rect, line, polyline, polygon, ellipse, g').forEach(updateEl)

    if (touched === 0) {
      console.warn('[IconColorFilter] No fill/stroke attributes found in SVG, icon may render with default color:', debugUrl)
    }
  },
  updateAllColors() {
    const color = localStorage.getItem('icon_preview_color') || '#212121'
    let count = 0
    this.el.querySelectorAll('.inline-svg-icon').forEach(icon => {
      const svg = icon.querySelector('svg')
      if (svg) {
        this.colorizeSvg(svg, color, icon.dataset.svgUrl)
        count++
      }
    })
    console.log(`[IconColorFilter] updateAllColors recolored ${count} icons to ${color}`)
  }
}

// Metrics tracker — exposes pushEvent for JS + filter persistence
Hooks.MetricsTracker = {
  mounted() {
    this.el._pushEvent = (event, params) => {
      this.pushEvent(event, params)
    }
    this.handleEvent("save_filters", ({styles, sizes, icon_sets}) => {
      localStorage.setItem("icon_filter_styles", JSON.stringify(styles))
      localStorage.setItem("icon_filter_sizes", JSON.stringify(sizes))
      localStorage.setItem("icon_filter_icon_sets", JSON.stringify(icon_sets))
    })
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

// ColorPicker hook — modal icon color preview with presets
Hooks.ColorPicker = {
  loadBuiltinPresets() {
    try {
      const arr = JSON.parse(this.el.dataset.presets || '[]')
      const map = {}
      for (const p of arr) {
        map[p.key] = { color: p.color, bg: p.bg, label: p.label }
      }
      return map
    } catch { return {} }
  },
  loadCustomPresets() {
    try { return JSON.parse(localStorage.getItem('icon_custom_presets') || '{}') } catch { return {} }
  },
  saveCustomPresets(presets) {
    localStorage.setItem('icon_custom_presets', JSON.stringify(presets))
  },
  allPresets() {
    return { ...this.loadBuiltinPresets(), ...this.loadCustomPresets() }
  },
  mounted() {
    this.colorInput = this.el.querySelector('.color-input')
    this.textInput = this.el.querySelector('.color-text')
    this.bgColorInput = this.el.querySelector('.bg-color-input')
    this.bgColorText = this.el.querySelector('.bg-color-text')
    this.renderCustomPresets()
    this.bindPresetButtons()
    this.applySaved()

    // Toggle button (More / Less)
    const toggleBtn = this.el.querySelector('.preview-preset-toggle')
    if (toggleBtn) {
      toggleBtn.addEventListener('click', () => {
        const list = this.el.querySelector('.preview-preset-list')
        if (!list) return
        const isExpanded = list.dataset.expanded === 'true'
        if (isExpanded) {
          this.collapsePresets()
        } else {
          this.expandPresets()
        }
      })
    }

    // Custom icon color inputs
    if (this.colorInput) {
      this.colorInput.addEventListener('input', (e) => {
        if (this.textInput) this.textInput.value = e.target.value
        localStorage.removeItem('icon_preview_preset')
        this.highlightPreset(null)
        this.updateSvgColors(e.target.value)
      })
    }
    if (this.textInput) {
      this.textInput.addEventListener('input', (e) => {
        let color = e.target.value
        if (color && !color.startsWith('#')) { color = '#' + color; this.textInput.value = color }
        if (/^#[0-9A-Fa-f]{6}$/.test(color)) {
          if (this.colorInput) this.colorInput.value = color
          localStorage.removeItem('icon_preview_preset')
          this.highlightPreset(null)
          this.updateSvgColors(color)
        }
      })
    }

    // Custom background color inputs
    if (this.bgColorInput) {
      this.bgColorInput.addEventListener('input', (e) => {
        if (this.bgColorText) this.bgColorText.value = e.target.value
        localStorage.setItem('icon_preview_bg', JSON.stringify(e.target.value))
        localStorage.removeItem('icon_preview_preset')
        this.highlightPreset(null)
        this.applyBg(e.target.value)
      })
    }
    if (this.bgColorText) {
      this.bgColorText.addEventListener('input', (e) => {
        let bg = e.target.value
        if (bg && !bg.startsWith('#')) { bg = '#' + bg; this.bgColorText.value = bg }
        if (/^#[0-9A-Fa-f]{6}$/.test(bg)) {
          if (this.bgColorInput) this.bgColorInput.value = bg
          localStorage.setItem('icon_preview_bg', JSON.stringify(bg))
          localStorage.removeItem('icon_preview_preset')
          this.highlightPreset(null)
          this.applyBg(bg)
        }
      })
    }

    // Copy CSS button
    const copyCssBtn = this.el.querySelector('.preview-copy-css')
    if (copyCssBtn) {
      copyCssBtn.addEventListener('click', () => {
        const css = this.generateCss()
        navigator.clipboard.writeText(css).then(() => {
          const orig = copyCssBtn.innerHTML
          copyCssBtn.innerHTML = '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg> Copied!'
          setTimeout(() => { copyCssBtn.innerHTML = orig }, 1500)
        })
      })
    }

    // Import CSS button + dialog
    const importBtn = this.el.querySelector('.preview-import-css')
    const importArea = this.el.querySelector('.preview-import-area')
    const importTextarea = this.el.querySelector('.preview-import-textarea')
    const importSubmit = this.el.querySelector('.preview-import-submit')
    const importCancel = this.el.querySelector('.preview-import-cancel')
    const importStatus = this.el.querySelector('.preview-import-status')

    if (importBtn && importArea) {
      importBtn.addEventListener('click', () => {
        importArea.style.display = importArea.style.display === 'none' ? '' : 'none'
        if (importArea.style.display !== 'none') importTextarea?.focus()
      })
    }
    if (importCancel) {
      importCancel.addEventListener('click', () => {
        importArea.style.display = 'none'
        if (importStatus) importStatus.textContent = ''
        if (importTextarea) importTextarea.value = ''
      })
    }
    if (importSubmit) {
      importSubmit.addEventListener('click', () => {
        const css = importTextarea?.value || ''
        const parsed = this.parseImportedCss(css)
        if (!parsed) {
          if (importStatus) {
            importStatus.textContent = 'Could not parse — need either a "Preset — Name [color: #..., background-color: #...]" comment, or at least a CSS rule with color: and background-color: properties.'
            importStatus.className = 'preview-import-status text-xs text-error'
          }
          return
        }
        // Save as custom preset
        const presets = this.loadCustomPresets()
        const key = `custom-${Date.now()}`
        presets[key] = { color: parsed.color, bg: parsed.bg, label: parsed.label }
        this.saveCustomPresets(presets)
        // Activate it
        localStorage.setItem('icon_preview_color', parsed.color)
        localStorage.setItem('icon_preview_bg', JSON.stringify(parsed.bg))
        localStorage.setItem('icon_preview_preset', key)
        this.renderCustomPresets()
        this.bindPresetButtons()
        if (this.colorInput) this.colorInput.value = parsed.color
        if (this.textInput) this.textInput.value = parsed.color
        if (this.bgColorInput) this.bgColorInput.value = parsed.bg
        if (this.bgColorText) this.bgColorText.value = parsed.bg
        // Update the custom-preset name input to reflect the just-imported preset
        const nameInput = this.el.querySelector('.custom-preset-name')
        if (nameInput) nameInput.value = parsed.label
        this.applyBg(parsed.bg)
        this.updateSvgColors(parsed.color)
        this.highlightPreset(key)
        this.renderActivePreset()
        // Expand the preset list so user can see the new preset highlighted
        this.expandPresets()
        if (importStatus) {
          importStatus.textContent = `Imported "${parsed.label}" — selected`
          importStatus.className = 'preview-import-status text-xs text-success'
        }
        if (importTextarea) importTextarea.value = ''
        setTimeout(() => {
          if (importStatus) importStatus.textContent = ''
          if (importArea) importArea.style.display = 'none'
        }, 2000)
      })
    }

    // Save as preset (creates new with timestamp ID, or updates active custom preset)
    const saveBtn = this.el.querySelector('.custom-preset-save')
    const nameInput = this.el.querySelector('.custom-preset-name')
    if (saveBtn && nameInput) {
      saveBtn.addEventListener('click', () => {
        const name = nameInput.value.trim()
        if (!name) {
          nameInput.focus()
          return
        }
        const color = this.colorInput ? this.colorInput.value : '#212121'
        const bg = this.bgColorInput ? this.bgColorInput.value : '#ffffff'
        const presets = this.loadCustomPresets()
        const activeKey = localStorage.getItem('icon_preview_preset')
        // If the active preset is a custom one, UPDATE it (keeps its ID).
        // Otherwise, create a new one with a timestamp-based ID.
        const key = (activeKey && presets[activeKey]) ? activeKey : `custom-${Date.now()}`
        presets[key] = { color, bg, label: name }
        this.saveCustomPresets(presets)
        this.renderCustomPresets()
        this.bindPresetButtons()
        // Activate the saved preset
        localStorage.setItem('icon_preview_preset', key)
        localStorage.setItem('icon_preview_color', color)
        localStorage.setItem('icon_preview_bg', JSON.stringify(bg))
        this.highlightPreset(key)
        this.renderActivePreset()
        this.expandPresets()
      })
    }
  },
  renderCustomPresets() {
    const container = this.el.querySelector('.custom-presets-container')
    if (!container) return
    container.innerHTML = ''
    const customs = this.loadCustomPresets()
    Object.entries(customs).forEach(([key, preset]) => {
      // Wrapper acts as the preset button
      const wrap = document.createElement('button')
      wrap.type = 'button'
      wrap.dataset.preset = key
      wrap.className = 'preview-preset inline-flex items-center rounded text-xs font-medium cursor-pointer border border-base-300 hover:scale-105 transition-transform overflow-hidden'

      // Colored label part (uses user's custom colors)
      const label = document.createElement('span')
      label.className = 'px-2.5 py-1'
      label.style.backgroundColor = preset.bg
      label.style.color = preset.color
      label.textContent = preset.label || key
      wrap.appendChild(label)

      // X delete button (uses theme colors)
      const del = document.createElement('span')
      del.textContent = '×'
      del.className = 'px-1.5 py-1 bg-base-300 text-base-content/70 hover:bg-error hover:text-error-content text-base leading-none border-l border-base-300'
      del.title = 'Delete preset'
      del.addEventListener('click', (e) => {
        e.stopPropagation()
        const presets = this.loadCustomPresets()
        delete presets[key]
        this.saveCustomPresets(presets)
        if (localStorage.getItem('icon_preview_preset') === key) {
          localStorage.removeItem('icon_preview_preset')
        }
        this.renderCustomPresets()
        this.bindPresetButtons()
      })
      wrap.appendChild(del)

      container.appendChild(wrap)
    })
  },
  bindPresetButtons() {
    this.el.querySelectorAll('.preview-preset').forEach(btn => {
      if (btn.dataset.bound === 'true') return
      btn.dataset.bound = 'true'
      btn.addEventListener('click', () => {
        const preset = this.allPresets()[btn.dataset.preset]
        if (!preset) return
        localStorage.setItem('icon_preview_color', preset.color)
        localStorage.setItem('icon_preview_bg', JSON.stringify(preset.bg))
        localStorage.setItem('icon_preview_preset', btn.dataset.preset)
        if (this.colorInput) this.colorInput.value = preset.color
        if (this.textInput) this.textInput.value = preset.color
        if (this.bgColorInput && preset.bg !== 'checker') this.bgColorInput.value = preset.bg
        if (this.bgColorText && preset.bg !== 'checker') this.bgColorText.value = preset.bg
        // If this is a custom preset, populate the name input so Save updates it instead of duplicating
        const customs = this.loadCustomPresets()
        const nameInput = this.el.querySelector('.custom-preset-name')
        if (nameInput) {
          if (customs[btn.dataset.preset]) {
            nameInput.value = preset.label || ''
          } else {
            nameInput.value = ''
          }
        }
        this.applyBg(preset.bg)
        this.updateSvgColors(preset.color)
        this.highlightPreset(btn.dataset.preset)
        this.renderActivePreset()
      })
    })
  },
  updated() {
    this.colorInput = this.el.querySelector('.color-input')
    this.textInput = this.el.querySelector('.color-text')
    this.bgColorInput = this.el.querySelector('.bg-color-input')
    this.bgColorText = this.el.querySelector('.bg-color-text')
    this.renderCustomPresets()
    this.bindPresetButtons()
    this.applySaved()
  },
  applySaved() {
    const savedColor = localStorage.getItem('icon_preview_color') || '#212121'
    let savedBg = '#ffffff'
    try { savedBg = JSON.parse(localStorage.getItem('icon_preview_bg') || '"#ffffff"') } catch { savedBg = localStorage.getItem('icon_preview_bg') || '#ffffff' }
    const savedPreset = localStorage.getItem('icon_preview_preset')
    requestAnimationFrame(() => {
      if (this.colorInput) this.colorInput.value = savedColor
      if (this.textInput) this.textInput.value = savedColor
      if (this.bgColorInput && savedBg !== 'checker') this.bgColorInput.value = savedBg
      if (this.bgColorText && savedBg !== 'checker') this.bgColorText.value = savedBg
      this.applyBg(savedBg)
      this.highlightPreset(savedPreset)
      this.renderActivePreset()
      this.collapsePresets()
    })
  },
  collapsePresets() {
    const list = this.el.querySelector('.preview-preset-list')
    const customArea = this.el.querySelector('.preview-custom-area')
    if (list) {
      list.dataset.expanded = 'false'
      list.style.display = 'none'
    }
    this.updateToggleButton(false)
    if (customArea) customArea.style.display = 'none'
  },
  expandPresets() {
    const list = this.el.querySelector('.preview-preset-list')
    const customArea = this.el.querySelector('.preview-custom-area')
    if (list) {
      list.dataset.expanded = 'true'
      list.style.display = ''
    }
    this.updateToggleButton(true)
    if (customArea) customArea.style.display = ''
  },
  updateToggleButton(expanded) {
    const label = this.el.querySelector('.preview-preset-toggle-label')
    const icon = this.el.querySelector('.preview-preset-toggle-icon')
    if (label) label.textContent = expanded ? 'Less' : 'More'
    if (icon) icon.style.transform = expanded ? 'rotate(180deg)' : ''
  },
  renderActivePreset() {
    const container = this.el.querySelector('.preview-preset-active')
    if (!container) return
    container.innerHTML = ''
    const activeKey = localStorage.getItem('icon_preview_preset')
    const all = this.allPresets()
    const preset = activeKey ? all[activeKey] : null

    if (!preset) {
      const span = document.createElement('span')
      span.className = 'text-xs text-base-content/50 italic'
      span.textContent = 'Custom'
      container.appendChild(span)
      return
    }

    // Find the matching button in the list (built-in or custom) and clone its style
    const sourceBtn = this.el.querySelector(`.preview-preset-list .preview-preset[data-preset="${activeKey}"]`)
    const clone = document.createElement('div')
    clone.className = 'inline-flex items-center rounded text-xs font-medium border border-primary overflow-hidden ring-2 ring-primary ring-offset-1'

    const label = document.createElement('span')
    label.className = 'px-2.5 py-1'
    if (preset.bg === 'checker') {
      label.style.backgroundImage = 'repeating-conic-gradient(#e5e7eb 0% 25%, #fff 0% 50%)'
      label.style.backgroundSize = '8px 8px'
      label.style.color = preset.color
    } else {
      label.style.backgroundColor = preset.bg
      label.style.color = preset.color
    }
    label.textContent = (preset.label || sourceBtn?.textContent?.replace('×', '').trim() || activeKey)
    clone.appendChild(label)
    container.appendChild(clone)
  },
  applyBg(bg) {
    // Modal preview boxes
    document.querySelectorAll('.svg-container').forEach(c => {
      c.style.removeProperty('background-image')
      c.style.removeProperty('background-size')
      c.className = c.className.replace(/bg-\S+/g, '')
      c.classList.add('rounded-lg', 'p-3', 'border', 'border-base-300', 'flex', 'items-center', 'justify-center')
      if (bg === 'checker') {
        c.style.backgroundImage = 'repeating-conic-gradient(#d1d5db 0% 25%, #fff 0% 50%)'
        c.style.backgroundSize = '12px 12px'
      } else {
        c.style.backgroundColor = bg
      }
    })
    // Grid / list icon wrappers
    document.querySelectorAll('.icon-preview-bg').forEach(el => {
      el.style.removeProperty('background-image')
      el.style.removeProperty('background-size')
      if (bg === 'checker') {
        el.style.backgroundImage = 'repeating-conic-gradient(#d1d5db 0% 25%, #fff 0% 50%)'
        el.style.backgroundSize = '8px 8px'
        el.style.backgroundColor = ''
      } else {
        el.style.backgroundColor = bg
      }
    })
  },
  // Parse pasted CSS to extract a preset.
  // Strategy 1: look for the "Preset — Name [color: #X, background: #Y]" comment
  // Strategy 2: extract the first background-color + color from any CSS rule
  parseImportedCss(css) {
    if (!css || !css.trim()) return null

    // Strategy 1: parse the preset comment (accepts both background: and background-color:)
    const presetCommentRe = /Preset\s*[—\-]\s*([^\(\[]+?)(?:\s*\([^)]+\))?\s*\[\s*color:\s*(#[0-9a-fA-F]{3,8})\s*,\s*background(?:-color)?:\s*(#[0-9a-fA-F]{3,8}|checker)\s*\]/i
    const m = css.match(presetCommentRe)
    if (m) {
      return {
        label: m[1].trim(),
        color: m[2].toLowerCase(),
        bg: m[3].toLowerCase()
      }
    }

    // Strategy 2: extract first background-color and color values
    const bgMatch = css.match(/background(?:-color)?\s*:\s*(#[0-9a-fA-F]{3,8})/i)
    const colorMatch = css.match(/(?:^|[^-])\bcolor\s*:\s*(#[0-9a-fA-F]{3,8})/i)
    if (bgMatch && colorMatch) {
      return {
        label: 'Imported',
        color: colorMatch[1].toLowerCase(),
        bg: bgMatch[1].toLowerCase()
      }
    }

    return null
  },
  generateCss() {
    const color = localStorage.getItem('icon_preview_color') || '#212121'
    let bg = '#ffffff'
    try { bg = JSON.parse(localStorage.getItem('icon_preview_bg') || '"#ffffff"') } catch { bg = localStorage.getItem('icon_preview_bg') || '#ffffff' }
    const colorMethod = this.el.dataset.colorMethod || 'fill'
    const iconSet = this.el.dataset.iconSet || ''
    const presetKey = localStorage.getItem('icon_preview_preset')
    const presetLabel = presetKey ? (this.allPresets()[presetKey]?.label || presetKey) : 'Custom'

    // CSS class derived from the preset's LABEL (not key) so renaming a custom preset
    // updates the CSS class too. Built-in preset keys already match the slug of their label.
    const cssClass = presetLabel.toLowerCase().replace(/[^a-z0-9]+/g, '-') || 'custom'

    // Selectors per icon set:
    //   scoped  — adds preset class so multiple presets can coexist
    //   global  — applies to ALL icons of this set, no scope
    let scopedSelector, globalSelector, scopedUsage, globalUsage
    if (iconSet === 'fontawesome') {
      scopedSelector = `i.${cssClass}.fa-solid, i.${cssClass}.fa-regular, i.${cssClass}.fa-brands`
      globalSelector = `i.fa-solid, i.fa-regular, i.fa-brands`
      scopedUsage = `<i class="${cssClass} fa-solid fa-arrow-right"></i>`
      globalUsage = `<i class="fa-solid fa-arrow-right"></i>`
    } else if (iconSet === 'tabler') {
      scopedSelector = `i.${cssClass}.ti`
      globalSelector = `i.ti`
      scopedUsage = `<i class="${cssClass} ti ti-arrow-right"></i>`
      globalUsage = `<i class="ti ti-arrow-right"></i>`
    } else {
      scopedSelector = `svg.${cssClass}`
      globalSelector = `svg`
      scopedUsage = `<Calendar className="${cssClass}" />`
      globalUsage = `<Calendar />  /* any icon component renders <svg> */`
    }

    // Header: identifies the preset so users can paste it back into icons.pureadmin.io to recreate it
    const presetHeader = `/* Preset — ${presetLabel} (${iconSet || 'icon'}) [color: ${color}, background-color: ${bg}] */`
    const colorMethodComment = `/* Color method: ${colorMethod} */`

    // Build a CSS rule body for a given selector
    const buildRule = (selector) => {
      const lines = [`${selector} {`]

      if (bg === 'checker') {
        lines.push(
          `  background-image: repeating-conic-gradient(#d1d5db 0% 25%, #fff 0% 50%);`,
          `  background-size: 12px 12px;`
        )
      } else {
        lines.push(`  background-color: ${bg};`)
      }

      if (colorMethod === 'multicolor') {
        lines.push(`  /* Multicolor icon — original SVG colors are preserved */`)
      } else if (colorMethod === 'stroke') {
        lines.push(
          `  color: ${color};`,
          `  stroke: currentColor;`,
          `  fill: none;`
        )
      } else {
        lines.push(
          `  color: ${color};`,
          `  fill: currentColor;`
        )
      }

      lines.push(`}`)
      return lines.join('\n')
    }

    return [
      `/* Generated by icons.pureadmin.io */`,
      presetHeader,
      colorMethodComment,
      ``,
      buildRule(scopedSelector),
      ``,
      `/* Usage: */`,
      `/* ${scopedUsage} */`,
      ``,
      ``,
      `/* ─────────────────────────────────────────────────── */`,
      `/* GLOBAL OVERRIDE — applies to ALL ${iconSet || 'icon'} icons   */`,
      `/* Use this if you want every icon styled the same way  */`,
      `/* ─────────────────────────────────────────────────── */`,
      ``,
      presetHeader,
      colorMethodComment,
      ``,
      buildRule(globalSelector),
      ``,
      `/* Usage: */`,
      `/* ${globalUsage} */`
    ].join('\n')
  },
  highlightPreset(active) {
    this.el.querySelectorAll('.preview-preset').forEach(btn => {
      if (btn.dataset.preset === active) {
        btn.classList.add('ring-2', 'ring-primary', 'ring-offset-1')
      } else {
        btn.classList.remove('ring-2', 'ring-primary', 'ring-offset-1')
      }
    })
  },
  updateSvgColors(color) {
    localStorage.setItem('icon_preview_color', color)
    const svgContainer = document.querySelector('[phx-hook="InlineSvg"]')
    if (svgContainer) {
      svgContainer.dataset.color = color
      svgContainer.querySelectorAll('svg path, svg circle, svg rect, svg line, svg polyline, svg polygon').forEach(el => {
        const currentFill = el.getAttribute('fill')
        if (currentFill && currentFill !== 'none') el.setAttribute('fill', color)
        const currentStroke = el.getAttribute('stroke')
        if (currentStroke && currentStroke !== 'none') el.setAttribute('stroke', color)
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
        const coloredSvg = svgText
          .replace(/fill="#[0-9A-Fa-f]{3,6}"/g, `fill="${color}"`)
          .replace(/fill="currentColor"/g, `fill="${color}"`)
          .replace(/stroke="#[0-9A-Fa-f]{3,6}"/g, `stroke="${color}"`)
          .replace(/stroke="currentColor"/g, `stroke="${color}"`)
        containers[i].innerHTML = coloredSvg
        const svg = containers[i].querySelector('svg')
        if (svg) { svg.style.width = `${containers[i].dataset.size}px`; svg.style.height = `${containers[i].dataset.size}px` }
      } catch (err) { console.error('Failed to load SVG:', err) }
    }
  }
}

// SvelteColor hook — toggles color in generated Svelte code (fluentui only)
Hooks.SvelteColor = {
  mounted() {
    const iconSet = this.el.dataset.iconSet
    const checkbox = this.el.querySelector('.svelte-include-color')
    // Color toggle only applies to fluentui's svelte-fluentui package
    if (!checkbox || iconSet !== 'fluentui') return
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

// FloatingPopover hook — uses floating-ui to position copy-button popovers above
// .has-popover triggers (size pills in grid view, size cells in list view).
// The popover element lives inside its trigger as a child with .floating-popover.
// We position it using strategy:'fixed' so ancestor overflow doesn't clip it.
Hooks.FloatingPopover = {
  mounted() {
    this.attach()
  },
  updated() {
    this.detach()
    this.attach()
  },
  destroyed() {
    this.detach()
  },
  attach() {
    if (!window.FloatingUIDOM) {
      console.warn('[FloatingPopover] floating-ui-dom global not loaded — popovers disabled')
      return
    }
    this.handlers = []
    this.el.querySelectorAll('.has-popover').forEach(trigger => {
      const popover = trigger.querySelector('.floating-popover')
      if (!popover) return

      let hideTimer = null
      const cancelHide = () => { if (hideTimer) { clearTimeout(hideTimer); hideTimer = null } }
      const scheduleHide = () => {
        cancelHide()
        hideTimer = setTimeout(() => this.hide(popover), 150)
      }
      const onTriggerEnter = () => { cancelHide(); this.show(trigger, popover) }
      const onTriggerLeave = scheduleHide
      const onPopoverEnter = cancelHide
      const onPopoverLeave = scheduleHide

      trigger.addEventListener('mouseenter', onTriggerEnter)
      trigger.addEventListener('mouseleave', onTriggerLeave)
      popover.addEventListener('mouseenter', onPopoverEnter)
      popover.addEventListener('mouseleave', onPopoverLeave)
      this.handlers.push({ trigger, popover, onTriggerEnter, onTriggerLeave, onPopoverEnter, onPopoverLeave })
    })
  },
  detach() {
    if (!this.handlers) return
    this.handlers.forEach(({ trigger, popover, onTriggerEnter, onTriggerLeave, onPopoverEnter, onPopoverLeave }) => {
      trigger.removeEventListener('mouseenter', onTriggerEnter)
      trigger.removeEventListener('mouseleave', onTriggerLeave)
      popover.removeEventListener('mouseenter', onPopoverEnter)
      popover.removeEventListener('mouseleave', onPopoverLeave)
      popover.classList.remove('popover-open')
    })
    this.handlers = []
  },
  show(trigger, popover) {
    popover.classList.add('popover-open')
    const { computePosition, offset, flip, shift } = window.FloatingUIDOM
    computePosition(trigger, popover, {
      strategy: 'fixed',
      placement: 'top',
      middleware: [offset(2), flip(), shift({ padding: 8 })]
    }).then(({ x, y }) => {
      popover.style.left = `${x}px`
      popover.style.top = `${y}px`
    })
  },
  hide(popover) {
    popover.classList.remove('popover-open')
  }
}

// IconSizeSlider hook — adjusts icon preview size in list/grid
Hooks.IconSizeSlider = {
  mounted() {
    console.time('[hook] IconSizeSlider.mounted')
    this.range = this.el.querySelector('.icon-size-range')
    this.label = this.el.querySelector('.icon-size-label')
    const saved = parseInt(localStorage.getItem('icon_list_size') || '32', 10)
    this.range.value = saved
    this.apply(saved)
    console.timeEnd('[hook] IconSizeSlider.mounted')
    this.range.addEventListener('input', () => {
      const size = parseInt(this.range.value, 10)
      localStorage.setItem('icon_list_size', size)
      this.apply(size)
    })
  },
  updated() {
    const saved = parseInt(localStorage.getItem('icon_list_size') || '32', 10)
    this.apply(saved)
  },
  apply(size) {
    if (this.label) this.label.textContent = size + 'px'
    // Update list view (desktop table)
    document.querySelectorAll('.icon-list-preview').forEach(el => {
      el.style.width = size + 'px'
      el.style.height = size + 'px'
    })
    // Update list view (mobile cards)
    document.querySelectorAll('.icon-card-preview').forEach(el => {
      el.style.width = (size * 1.5) + 'px'
      el.style.height = (size * 1.5) + 'px'
    })
  }
}

// DownloadNaming hook — lets users pick a filename convention for SVG downloads
Hooks.DownloadNaming = {
  mounted() {
    this.select = this.el.querySelector('.download-naming-select')
    this.name = this.el.dataset.name
    this.style = this.el.dataset.style
    if (!this.select) return
    const saved = localStorage.getItem('download_naming') || 'original'
    this.select.value = saved
    this.applyNaming(saved)
    this.select.addEventListener('change', () => {
      localStorage.setItem('download_naming', this.select.value)
      this.applyNaming(this.select.value)
    })
  },
  updated() {
    this.select = this.el.querySelector('.download-naming-select')
    this.name = this.el.dataset.name
    this.style = this.el.dataset.style
    if (this.select) this.applyNaming(this.select.value || 'original')
  },
  applyNaming(convention) {
    const toSnake = s => s.toLowerCase().replace(/\s+/g, '_')
    const toPascal = s => s.split(/\s+/).map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join('')
    const toKebab = s => s.toLowerCase().replace(/\s+/g, '-')

    this.el.querySelectorAll('.download-link').forEach(link => {
      const original = link.dataset.originalFilename || ''
      if (!original) return
      const extMatch = original.match(/\.[a-z0-9]+$/i)
      const ext = extMatch ? extMatch[0] : ''
      const size = link.dataset.size

      let baseName
      switch (convention) {
        case 'kebab': baseName = toKebab(this.name); break
        case 'snake': baseName = toSnake(this.name); break
        case 'pascal': baseName = toPascal(this.name); break
        default: link.setAttribute('download', original); return
      }
      // Append size suffix only when the original filename had it (e.g. heroicons "name-24.svg")
      // and we're not in scalable mode
      const hasSizeInOriginal = size && size !== '0' && original.includes(`-${size}`)
      const sizeSuffix = hasSizeInOriginal ? `-${size}` : ''
      link.setAttribute('download', `${baseName}${sizeSuffix}${ext}`)
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
    const filenamesMap = JSON.parse(this.el.dataset.filenames || '{}')
    const resultsContainer = this.el.querySelector("[id^='filename-results']")
    if (!resultsContainer) return
    const toSnake = s => s.toLowerCase().replace(/\s+/g, '_')
    const toPascal = s => s.split(/\s+/).map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join('')
    const toKebab = s => s.toLowerCase().replace(/\s+/g, '-')
    resultsContainer.innerHTML = sizes.map(size => {
      // Look up the real filename from the server-provided map (handles all icon sets correctly)
      // Falls back to the first available filename for scalable icons
      const origFilename = filenamesMap[String(size)] || Object.values(filenamesMap)[0] || ''
      // Extract extension from original filename so we can append it when user uses placeholders
      // that don't include it (e.g. {name_kebab})
      const extMatch = origFilename.match(/\.[a-z0-9]+$/i)
      const ext = extMatch ? extMatch[0] : ''
      const usesFilenamePlaceholder = template.includes('{filename}')
      let filename = template.replace(/{filename}/g, origFilename).replace(/{name}/g, name)
        .replace(/{name_snake}/g, toSnake(name)).replace(/{name_pascal}/g, toPascal(name))
        .replace(/{name_kebab}/g, toKebab(name)).replace(/{size}/g, size).replace(/{style}/g, style)
      // Append the extension if the template doesn't already end with one and didn't use {filename}
      if (!usesFilenamePlaceholder && ext && !filename.toLowerCase().endsWith(ext.toLowerCase())) {
        filename += ext
      }
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
  let { text, platform, filename, name, style, size, icon_id } = event.detail
  // For filename platform, apply the saved template
  if (platform === 'filename' && filename) {
    const template = localStorage.getItem('filename_template') || '{filename}'
    const toSnake = s => s.toLowerCase().replace(/\s+/g, '_')
    const toPascal = s => s.split(/\s+/).map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join('')
    const toKebab = s => s.toLowerCase().replace(/\s+/g, '-')
    text = template
      .replace(/{filename}/g, filename)
      .replace(/{name}/g, name)
      .replace(/{name_snake}/g, toSnake(name))
      .replace(/{name_pascal}/g, toPascal(name))
      .replace(/{name_kebab}/g, toKebab(name))
      .replace(/{size}/g, size)
      .replace(/{style}/g, style)
  }
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
      // Track copy on server
      if (icon_id && platform) {
        const metricsEl = document.getElementById('metrics-tracker')
        if (metricsEl && metricsEl._pushEvent) {
          metricsEl._pushEvent("track_copy", { "icon-id": String(icon_id), platform, size: String(size || '') })
        }
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
        // Track copy on server
        const metricsEl = document.getElementById('metrics-tracker')
        if (metricsEl && metricsEl._pushEvent && target.id) {
          // target.id is like "ios-1234-24" or "react-1234-16"
          const parts = target.id.split('-')
          if (parts.length >= 3) {
            const platform = parts[0]
            const iconId = parts[1]
            const size = parts[parts.length - 1]
            metricsEl._pushEvent("track_copy", { "icon-id": iconId, platform, size })
          }
        }
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

console.time('[prefs] LiveSocket init')
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {
    _csrf_token: csrfToken,
    view_mode: localStorage.getItem("icon_view_mode") || "grid",
    icon_list_size: parseInt(localStorage.getItem("icon_list_size") || "32", 10),
    platform_prefs: JSON.parse(localStorage.getItem("icon_platform_prefs") || "{}"),
    filter_styles: JSON.parse(localStorage.getItem("icon_filter_styles") || "[]"),
    filter_sizes: JSON.parse(localStorage.getItem("icon_filter_sizes") || "[]"),
    filter_icon_sets: JSON.parse(localStorage.getItem("icon_filter_icon_sets") || "[]")
  },
  hooks: Hooks
})
console.timeEnd('[prefs] LiveSocket init')
console.log('[prefs] connect_params:', {
  view_mode: localStorage.getItem("icon_view_mode"),
  icon_list_size: localStorage.getItem("icon_list_size"),
  filter_icon_sets: localStorage.getItem("icon_filter_icon_sets")
})

topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => { console.time('[phx] page-load'); topbar.show(300) })
window.addEventListener("phx:page-loading-stop", _info => {
  console.timeEnd('[phx] page-load')
  topbar.hide()
  // Hide loader after first LiveView connect
  const loader = document.getElementById('app-loader')
  if (loader) {
    loader.style.opacity = '0'
    setTimeout(() => loader.remove(), 300)
  }
})

liveSocket.connect()
window.liveSocket = liveSocket


// Time-of-day theme manager
import { startAutoUpdate, initThemeEvents } from "./theme-manager"
startAutoUpdate()
initThemeEvents()
// Theme transitions disabled — instant switch
// setTimeout(() => document.documentElement.classList.add("theme-transitions"), 100)

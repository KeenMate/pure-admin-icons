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
      const coloredSvg = svgText
        .replace(/fill="#[0-9A-Fa-f]{3,6}"/g, `fill="${color}"`)
        .replace(/fill="currentColor"/g, `fill="${color}"`)
        .replace(/stroke="#[0-9A-Fa-f]{3,6}"/g, `stroke="${color}"`)
        .replace(/stroke="currentColor"/g, `stroke="${color}"`)
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
      icon.querySelectorAll('svg path, svg circle, svg rect, svg line, svg polyline, svg polygon').forEach(el => {
        const currentFill = el.getAttribute('fill')
        if (currentFill && currentFill !== 'none') el.setAttribute('fill', color)
        const currentStroke = el.getAttribute('stroke')
        if (currentStroke && currentStroke !== 'none') el.setAttribute('stroke', color)
      })
    })
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

    // Save as preset
    const saveBtn = this.el.querySelector('.custom-preset-save')
    const nameInput = this.el.querySelector('.custom-preset-name')
    if (saveBtn && nameInput) {
      saveBtn.addEventListener('click', () => {
        const name = nameInput.value.trim()
        if (!name) {
          nameInput.focus()
          return
        }
        const key = 'custom-' + name.toLowerCase().replace(/[^a-z0-9]+/g, '-')
        const color = this.colorInput ? this.colorInput.value : '#212121'
        const bg = this.bgColorInput ? this.bgColorInput.value : '#ffffff'
        const presets = this.loadCustomPresets()
        presets[key] = { color, bg, label: name }
        this.saveCustomPresets(presets)
        nameInput.value = ''
        this.renderCustomPresets()
        this.bindPresetButtons()
        // Activate the newly saved preset
        localStorage.setItem('icon_preview_preset', key)
        this.highlightPreset(key)
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
    const toggle = this.el.querySelector('.preview-preset-toggle')
    const customArea = this.el.querySelector('.preview-custom-area')
    if (list) {
      list.dataset.expanded = 'false'
      list.style.display = 'none'
    }
    if (toggle) toggle.textContent = 'More ▾'
    if (customArea) customArea.style.display = 'none'
  },
  expandPresets() {
    const list = this.el.querySelector('.preview-preset-list')
    const toggle = this.el.querySelector('.preview-preset-toggle')
    const customArea = this.el.querySelector('.preview-custom-area')
    if (list) {
      list.dataset.expanded = 'true'
      list.style.display = ''
    }
    if (toggle) toggle.textContent = 'Less ▴'
    if (customArea) customArea.style.display = ''
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
  generateCss() {
    const color = localStorage.getItem('icon_preview_color') || '#212121'
    let bg = '#ffffff'
    try { bg = JSON.parse(localStorage.getItem('icon_preview_bg') || '"#ffffff"') } catch { bg = localStorage.getItem('icon_preview_bg') || '#ffffff' }
    const colorMethod = this.el.dataset.colorMethod || 'fill'
    const iconSet = this.el.dataset.iconSet || ''
    const presetKey = localStorage.getItem('icon_preview_preset')
    const presetLabel = presetKey ? (this.allPresets()[presetKey]?.label || presetKey) : 'Custom'

    // CSS class derived from preset key (already kebab-case lowercase) or 'custom'
    const cssClass = presetKey ? presetKey.toLowerCase().replace(/[^a-z0-9]+/g, '-') : 'custom'

    // Pick selector strategy based on icon set
    // - Font Awesome: scope existing FA classes with the preset class
    // - Tabler webfont: scope existing ti class with the preset class
    // - SVG sets (Lucide, Heroicons, FluentUI): targets svg.{cssClass} directly
    let selector, usage
    if (iconSet === 'fontawesome') {
      selector = `i.${cssClass}.fa-solid, i.${cssClass}.fa-regular, i.${cssClass}.fa-brands`
      usage = `<i class="${cssClass} fa-solid fa-arrow-right"></i>`
    } else if (iconSet === 'tabler') {
      selector = `i.${cssClass}.ti`
      usage = `<i class="${cssClass} ti ti-arrow-right"></i>`
    } else {
      selector = `svg.${cssClass}`
      usage = `<Calendar className="${cssClass}" />  /* React */\n   <Calendar class="${cssClass}" />     /* Vue/Svelte */\n   <svg class="${cssClass}">...</svg>   /* Plain HTML */`
    }

    const lines = [
      `/* Icon preview — ${presetLabel} (${iconSet || 'icon'}) */`,
      `/* Color method: ${colorMethod} */`,
      ``,
      `${selector} {`,
    ]

    if (bg === 'checker') {
      lines.push(
        `  background-image: repeating-conic-gradient(#d1d5db 0% 25%, #fff 0% 50%);`,
        `  background-size: 12px 12px;`
      )
    } else {
      lines.push(`  background-color: ${bg};`)
    }

    if (colorMethod === 'multicolor') {
      lines.push(`  /* Multicolor icon — colors come from the icon itself */`)
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

    lines.push(`}`, ``, `/* Usage: */`, `/* ${usage} */`)

    return lines.join('\n')
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

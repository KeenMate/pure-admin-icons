# Copy CSS Feature

The "Copy CSS" button in the icon detail modal generates ready-to-paste CSS that styles icons with the active preset's colors. The output is **icon-set-aware** — the selector and color properties depend on the icon set's API.

## What it generates

For Font Awesome with the "Red planet" custom preset:

```css
/* Icon preview — Red planet (fontawesome) */
/* Color method: fill */

i.red-planet.fa-solid, i.red-planet.fa-regular, i.red-planet.fa-brands {
  background-color: #000000;
  color: #fb2323;
  fill: currentColor;
}

/* Usage: */
/* <i class="red-planet fa-solid fa-arrow-right"></i> */
```

The user pastes the CSS into their stylesheet and the HTML into their template — no other setup needed beyond having Font Awesome already loaded.

## Selector strategy per icon set

| Icon set | Selector | Why |
|----------|----------|-----|
| `fontawesome` | `i.{class}.fa-solid, i.{class}.fa-regular, i.{class}.fa-brands` | Targets `<i>` tags rendered by Font Awesome web font, scoped to the preset class so it doesn't bleed into other icons |
| `tabler` | `i.{class}.ti` | Targets Tabler webfont `<i>` elements |
| Other (Lucide, Heroicons, FluentUI) | `svg.{class}` | Targets the SVG element directly. Works with React/Vue/Svelte components that accept a `className`/`class` prop, or plain inline SVG markup |

## Color method awareness

Each icon's `style_color_method` field (returned by the DB) determines which CSS properties to set:

| Color method | CSS output |
|--------------|------------|
| `fill` | `color: <color>; fill: currentColor;` |
| `stroke` | `color: <color>; stroke: currentColor; fill: none;` |
| `multicolor` | `/* Multicolor icon — colors come from the icon itself */` (no override) |

This means a Lucide icon (stroke-based) gets different CSS than a FluentUI icon (fill-based) even with the same preset, and a multicolor FluentUI icon gets a no-op comment instead of breaking the gradients.

## CSS class derived from preset key

The CSS class name comes from the preset's `key` field (already kebab-case lowercase). For custom presets, the key is generated from the user's chosen name:

```
"Neon Dark" → preset key "neon-dark" → CSS class .neon-dark
"My cool theme" (custom) → key "custom-my-cool-theme" → CSS class .custom-my-cool-theme
```

## Implementation

The button is wired up in the `ColorPicker` JS hook (`assets/js/app.js`). The `generateCss()` method:

1. Reads the active color, background, and color method from the hook's data attributes and localStorage
2. Picks the appropriate selector strategy based on `data-icon-set`
3. Builds the CSS string line by line
4. Returns a complete, ready-to-paste CSS block

The button click handler copies the result via `navigator.clipboard.writeText()` and shows a brief "Copied!" feedback.

## Why we don't include layout/padding

Earlier iterations included `display: inline-flex; padding: 8px; border-radius: 8px;` etc. These were removed because:

- The icon sets' own CSS already handles display, sizing, alignment
- Forcing layout properties would conflict with the user's existing design
- The preset is purely about **color** — let the user keep their layout

The output is now minimal: just `background-color`, `color`, and the appropriate `fill`/`stroke` value.

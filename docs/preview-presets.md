# Preview Presets

The icon detail modal lets users preview icons against pre-configured color combinations ("presets") and create their own custom presets.

## Source of truth

Built-in presets live in **`priv/preview_presets.json`** as an array of objects:

```json
{
  "key": "neon-dark",
  "label": "Neon Dark",
  "color": "#4ade80",
  "bg": "#000000"
}
```

| Field | Description |
|-------|-------------|
| `key` | Stable identifier, kebab-case lowercase. Used as the CSS class name in the "Copy CSS" output and as the localStorage key for the active preset. |
| `label` | Display name shown on the button. Free-form. |
| `color` | Hex color for the icon (the `color`/`fill`/`stroke` value). |
| `bg` | Hex color for the background, OR the literal string `"checker"` for a transparency checkerboard pattern. |

## How it's loaded

The JSON is loaded **at compile time** in `lib/pure_admin_icons_web/live/icon_search_live.ex`:

```elixir
@preview_presets :pure_admin_icons
                 |> :code.priv_dir()
                 |> Path.join("preview_presets.json")
                 |> File.read!()
                 |> Jason.decode!()
@external_resource Path.join(:code.priv_dir(:pure_admin_icons), "preview_presets.json")
```

The `@external_resource` ensures Mix recompiles the LiveView whenever the JSON changes.

## How it's rendered

In the modal template, presets render via a `for` loop:

```heex
<%= for preset <- preview_presets() do %>
  <button data-preset={preset["key"]} style={preset_button_style(preset)}>
    <%= preset["label"] %>
  </button>
<% end %>
```

`preset_button_style/1` generates inline `background-color` + `color` CSS so the buttons preview the actual colors. The checker preset uses a `repeating-conic-gradient` instead.

## How JavaScript reads the same data

The same JSON is passed to the `ColorPicker` JS hook via a `data-presets` attribute on the hook element:

```heex
<div phx-hook="ColorPicker" data-presets={Jason.encode!(preview_presets())} ...>
```

The JS hook parses this in `loadBuiltinPresets()` so the server is the single source of truth — the JSON file drives both the buttons and the color application.

## Custom presets

Users can save their own combinations via the "Custom" panel inside the expanded preset list:

- **Storage:** `localStorage["icon_custom_presets"]` as `{key: {color, bg, label}}`
- **Key generation:** `"custom-" + name.toLowerCase().replace(/[^a-z0-9]+/g, '-')`
- **UI:** Each custom preset renders as a button with the user's colors plus a theme-styled `×` delete button
- **Lifecycle:** Custom presets are merged into `allPresets()` alongside built-ins, so they show up in the same list and work identically with Copy CSS

## Active preset

The currently selected preset is stored in `localStorage["icon_preview_preset"]` (the key, not the full object). The active preset is rendered in a fixed position next to the "Preview:" label so the layout doesn't jump when toggling the More/Less list.

## Adding a new built-in preset

1. Edit `priv/preview_presets.json` and add a new entry
2. Save — Mix will recompile the LiveView automatically
3. The new preset appears in the modal and is also available to JS via `data-presets`

No JS changes needed.

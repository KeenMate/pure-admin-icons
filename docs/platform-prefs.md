# Per-Icon-Set Platform Preferences

The icon detail modal lets users toggle which platform identifiers (iOS, Android, React, Vue, Svelte, CSS Class, HTML Tag, Filename) are shown. These preferences are stored **per icon set** because not every set supports every platform.

## Why per-set?

- FluentUI doesn't have a CSS class API → "CSS Class" toggle is hidden
- Heroicons / Lucide / FluentUI don't have web fonts → "HTML Tag" is hidden
- A user looking at FluentUI typically wants React/iOS/Android, but the same user looking at Font Awesome wants CSS Class / HTML Tag
- Sharing one global preference forces re-toggling every time you switch sets

## Storage shape

In `localStorage["icon_platform_prefs"]`:

```json
{
  "fluentui":    { "ios": true, "android": true, "react": true, "filename": true },
  "fontawesome": { "react": true, "vue": true, "cssclass": true, "htmltag": true, "filename": true },
  "heroicons":   { "react": true, "svelte": true }
}
```

Each top-level key is an icon set code, and the value is the platform preferences map for that set. Missing sets fall back to the default (all platforms enabled).

## Migration from legacy flat shape

Earlier versions stored prefs as a single flat map:

```json
{ "ios": true, "android": false, "react": true }
```

The `parse_platform_prefs/1` function in `icon_search_live.ex` detects this shape (top-level keys match known platform names rather than icon set codes) and applies the flat prefs to **all** known sets on first load. After that, users can diverge per set.

## Server-side flow

1. **Mount:** `connect_params["platform_prefs"]` is parsed by `parse_platform_prefs/1` → assigned to `:platform_prefs_by_set`. The active `:platform_prefs` is set to defaults until an icon is selected.

2. **Select icon:** `handle_event("select_icon", ...)` looks up `prefs_for_set(prefs_by_set, icon.icon_set_code)` and assigns it to `:platform_prefs`. This is the active prefs the modal renders.

3. **Toggle a platform:** `handle_event("toggle_platform", ...)` updates the active `:platform_prefs`, also updates the per-set storage `:platform_prefs_by_set`, and pushes the whole map to JS via `push_event("save_platform_prefs", ...)`.

4. **JS save:** The `MetricsTracker` hook receives the `save_platform_prefs` event and writes the entire map back to `localStorage["icon_platform_prefs"]`.

## Helper functions

- `default_platform_prefs/0` — returns `%{ios: true, android: true, react: true, vue: true, svelte: true, cssclass: true, htmltag: true, filename: true}`
- `prefs_for_set/2` — returns the saved prefs for a set, merged with defaults so newly added platforms appear enabled
- `parse_platform_prefs/1` — handles both new (per-set) and legacy (flat) shapes
- `atomize_pref_values/1` — JSON keys come back as strings; this converts them to atoms

## What's not stored per-set

The **filter prefs** (selected icon sets, styles, sizes) are still global because they apply across the search, not per icon. Same for view mode, icon list size, and color preset.

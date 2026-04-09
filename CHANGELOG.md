# Changelog

## 2026-04-09 — Per-icon platform popover fix

### Grid/list popover buttons leaked across icon sets
- The hover popover on grid pills and list checkmarks used a single global `@platform_prefs` for **all** icons regardless of icon set, so every icon (Heroicons, Lucide, Tabler, Font Awesome) was showing iOS/Android copy buttons — even though only FluentUI has native iOS/Android distributions
- After opening any icon detail modal, `@platform_prefs` got replaced by that one icon's per-set prefs and then leaked back into all the grid/list buttons (e.g., open a Heroicons icon → close → now every icon in the grid shows Svelte/CSS Class buttons)
- New helper `preferred_platforms_for/3` resolves the prefs **per icon**: looks up the icon's set's own prefs from `@platform_prefs_by_set`, then filters to only the platforms the set actually supports (via `Formatter.{ios,android,react,vue,svelte,cssclass}_package(icon)` returning a non-nil package name)
- New helpers `platform_supported?/2` and `package_present?/1` perform the support check
- `icon_grid` and `icon_list` now receive `platform_prefs_by_set={@platform_prefs_by_set}` instead of the global `platform_prefs` and use `preferred_platforms_for(icon, @platform_prefs_by_set, 2)` at the four popover call sites — each icon now shows only the platforms relevant to its own set, computed independently
- The modal still uses `@platform_prefs` since it only ever shows one icon at a time and the existing `select_icon` handler already populates that correctly

---

## 2026-04-09 — Floating-UI popovers, semantic CSS extraction, control polish ✅ PUBLISHED

### Floating-UI for copy-button popovers
- Vendored `@floating-ui/core@1.6.9` and `@floating-ui/dom@1.6.13` UMD bundles into `priv/static/assets/vendor/`, loaded via `<script defer>` in `root.html.heex` before `app.js`
- New `Hooks.FloatingPopover` JS hook (attached to a `#icon-display-popovers` wrapper around `#icon-display`) — uses event delegation to find `.has-popover` triggers and position their child `.floating-popover` element
- Uses `computePosition` with `strategy: 'fixed'` so ancestor `overflow:hidden` (table wrapper) no longer clips popovers
- Middleware: `offset(2)` (sits 2px above trigger so cursor barely needs to traverse a gap), `flip()` (auto-flips below if no room above), `shift({padding: 8})` (slides horizontally to stay within viewport)
- 150ms hide-debounce so the user can move from trigger to popover without it disappearing; cancelled by `mouseenter` on the popover itself
- **Grid view** — size pills (`24px`, `∞`) replaced their `.size-cell` + `.size-popover` markup with the unified `.has-popover` pattern
- **List view** — `✓` checkmarks and `∞ Scalable` cells replaced the old `.list-cell-hover` opacity-overlay pattern with the same `.has-popover` markup
- Size column widths reverted to compact `w-16` — popovers no longer affect column layout since they float on top of neighboring cells

### Semantic CSS class extraction
- Added one block of semantic component classes at the bottom of `app.css` to replace repeated utility-class soup in templates
- New classes: `.view-toggle`, `.btn-action`, `.btn-pager` / `.btn-pager-disabled`, `.icon-card-body`, `.icon-card-name`, `.icon-card-thumb`, `.icon-card-sizes`, `.list-row`, `.has-popover`, `.floating-popover`, `.floating-popover-btn`
- `icon_grid` and `icon_list` templates significantly slimmer — popover-button markup now writes once and applies to all 4 places (grid scalable, grid sized, list scalable, list sized)
- Renamed grid card `.icon-card-preview` → `.icon-card-thumb` to avoid colliding with the existing JS slider hook that targets `.icon-card-preview` for the **mobile** card layout

### Pager and control polish
- **Pager buttons** (Previous / Next) now use `btn btn-sm btn-ghost border border-base-content/20` matching `pure-admin-io`'s ghost button style — clearly visible white borders in night theme (was unstyled `bg-base-300` blending into the background)
- **Top pager moved** out of the hero `max-w-5xl` section into the main `max-w-7xl` content area so it aligns vertically with the bottom pager regardless of view mode
- **View toggle wrapper** (Grid/List segmented control) and the Filters button now both have visible `border-base-content/20` outlines for consistency with the new ghost-button style

---

## 2026-04-08 — MCP package rename

- All references to `@keenmate/fluentui-icons-mcp` updated to the new `@keenmate/pure-admin-icons-mcp` package
- Updated home page MCP link, API docs MCP example, MCP docs page (Claude Desktop config + Claude Code command)
- Claude Desktop config example now uses Windows-friendly form: `npx -y -p @keenmate/pure-admin-icons-mcp pure-admin-icons-mcp`

---

## 2026-04-08 — Honest platforms, download naming, mobile polish ✅ PUBLISHED

### Honest platform identifiers
- iOS and Android sections only shown for icon sets that have **real** native distributions (currently only FluentUI)
- Removed the fake `calendar24` / `ic_heroicons_calendar_24_solid` style identifiers that were generated for icon sets without iOS/Android packages (Heroicons, Lucide, Tabler, Font Awesome Free)
- iOS/Android section headers now include linked package name like the other platforms
- Two new behaviour callbacks `ios_package/1` and `android_package/1` on `IconSets.Formatter` — only FluentUI returns non-nil

### Download filename naming
- New "Filename:" dropdown next to "Available Sizes" in the detail modal
- Choose **Original / kebab-case / snake_case / PascalCase** for SVG downloads
- Selection persists to localStorage
- Extension preserved from the original filename
- Heroicons-style icons keep their `-{size}` suffix when the original had one

### Filename template fix
- `{filename}` placeholder now uses the **real filename from the DB** instead of hardcoded `ic_fluent_*` (was a leftover from FluentUI-only days)
- When using `{name_kebab}` etc, the extension is auto-appended from the original filename if not already present

### Grid layout polish
- Card grid now uses `flex flex-wrap justify-center` with fixed `w-44` cards — results centered horizontally regardless of count
- "Showing 1-30 of N icons" hidden when there are zero results
- "Filters" / "Grid" / "List" buttons show only icons on mobile (labels appear at `sm` breakpoint)

### Svelte code formatting
- Heroicons Svelte identifier now respects newline (`whitespace-pre-line` added to the `<code>` element)
- Import line and `<Icon>` line now appear on separate lines

---

## 2026-04-08 — Universal/scalable size, grid sizes polish ✅ PUBLISHED

### Universal "Scalable" size
- New `is_scalable` flag (DB-side) for icon sets that have a single SVG that scales to any size
- **Lucide, Tabler, Font Awesome** marked as scalable — instead of pretending they're "24px", we now show them as scalable
- **FluentUI and Heroicons** stay non-scalable since they have hand-tuned variants per size
- **Grid card** shows `∞` symbol (large, bold) with hover-to-copy popup for scalable icons
- **List view (mobile)** shows `∞` badge instead of size badges
- **List view (desktop)** uses `colspan` to merge size columns into a single "∞ Scalable" cell with hover-to-copy
- **Detail modal** shows a single "Preview — Scalable, renders at any size" with one preview at 96px instead of multiple size previews
- **Sizes filter** gets a new "∞ Scalable" pseudo-checkbox at the top (only when scalable sets exist in the union)
- **Active filter badges** show "∞ Scalable" instead of "0px"
- **API responses** include `is_scalable` flag on icons and icon sets
- **Search context** translates `size: 0` filter to `is_scalable: true` criterion
- **Icon helpers** — `Icon.svg_url`, `Icon.svg_filename` ignore the size argument for scalable icons
- **Formatter modules** — identifier sizes return `[0]` for scalable icons so the modal renders one row instead of looping

### Grid card sizes polish
- Sizes use a custom `font-size: 0.8rem` with `font-semibold` and primary color
- ∞ symbol is `text-2xl font-bold` so it stands out as the focal point
- ∞ symbol in detail modal preview is `text-3xl font-bold` (was tiny `text-xs`)

### Preset toggle button
- "More / Less" button now uses an SVG chevron icon on the left, matching the Copy CSS / Import CSS button style
- Icon rotates 180° when expanded (down → up chevron) with smooth transition
- Label is a separate `<span>` so it can be swapped without re-rendering the icon

---

## 2026-04-08 — Grid card redesign ✅ PUBLISHED

### Grid card layout
- **Top accent bar** colored by icon set (blue=fluentui, violet=heroicons, orange=lucide, cyan=tabler, yellow=fontawesome) — replaces the icon set badge, follows card's rounded corners
- **Title moved to top** above the icon
- **Style badge under the title** (centered) — only shown when the result set contains multiple styles, hidden when all icons share one style
- **Larger icon preview** (w-20 h-20 wrapper, w-12 h-12 icon — was 16/10)
- **Sizes at bottom**, expanded (all sizes shown inline as plain text, wrap to multiple lines for FluentUI's 6 sizes)
- Card title attribute shows full `set / name` on hover

### Tooltip fix
- Removed `overflow-hidden` from icon cards so hover-to-copy tooltips can escape card boundaries
- Top accent bar now uses `rounded-t-lg` directly to keep matching the card's rounded corners
- Tooltips bumped to `z-50` so they appear above adjacent cards

---

## 2026-04-08 — Icon set formatter modules, Import CSS, Copy CSS dual block ✅ PUBLISHED

### Refactor: per-icon-set formatter modules
- All icon-set-specific identifier and package logic moved out of `icon_search_live.ex`
- New `lib/pure_admin_icons/icon_sets/` folder with one module per icon set:
  - `formatter.ex` — behaviour + dispatcher (registry + delegating helpers)
  - `generic.ex` — fallback for unknown sets
  - `fluentui.ex`, `fontawesome.ex`, `heroicons.ex`, `lucide.ex`, `tabler.ex`
- Each module implements `PureAdminIcons.IconSets.Formatter` behaviour with React/Vue/Svelte/CSS class identifiers and package metadata
- LiveView now has thin delegating wrappers — adding a new icon set requires creating one file in `icon_sets/` and registering it in `formatter.ex`'s `@formatters` map
- Removed ~150 lines of pattern-matched clauses from the LiveView

### Copy CSS — dual block output
- Output now includes both a **scoped** rule (with preset class) and a **global override** rule (no scope)
- New header format: `/* Generated by icons.pureadmin.io */`
- Preset comment is machine-parseable: `/* Preset — Transit (fontawesome) [color: #000000, background-color: #fbbf24] */`
- Both blocks share the same identifying header so users can paste either back to recreate the preset
- More professional comment formatting throughout

### Import CSS
- New "Import CSS" button next to "Copy CSS" — opens a paste textarea
- Two parsing strategies:
  1. **Preset comment** — parses `/* Preset — Name [color: #..., background-color: #...] */` to recover label + colors
  2. **Fallback** — extracts the first `color:` and `background-color:` from any CSS rule (label defaults to "Imported")
- Successful import creates a custom preset, activates it immediately, and updates all live previews
- Backwards compatible: accepts both `background:` and `background-color:` in the preset comment

---

## 2026-04-08 — Per-set platform prefs, CSS class platform, preview presets, Copy CSS ✅ PUBLISHED

### Per-icon-set platform preferences
- Platform toggle prefs (iOS, React, Vue, Svelte, etc.) are now stored **per icon set** in localStorage
- Switching from FluentUI to Font Awesome remembers each set's separate selection
- Migration: legacy flat shape is auto-applied to all sets on first load

### CSS Class & HTML Tag platforms
- New `cssclass` platform — bare class string (e.g., `fa-solid fa-arrow-right`) for menu configs, JSON, etc.
- New `htmltag` platform — full `<i class="..."></i>` element ready to paste
- Both only shown for Font Awesome and Tabler (icon sets with web font APIs)
- Hidden for FluentUI, Heroicons, Lucide

### Preview presets
- 10 built-in color presets: Classic Light/Dark, Neon Dark, Blueprint, Warm, Transit, Transit Inv, Expressway, Road Sign, Transparent
- Loaded from `priv/preview_presets.json` (single source of truth, shared between server and client)
- Custom presets — user can save their own color combinations with custom names
- Custom preset badges have a dedicated theme-colored × delete button
- Active preset always visible next to "Preview:" label, others hidden behind "More ▾" toggle
- Selecting a preset updates icon previews live across grid, list, and detail modal
- Background color picker added (separate from icon color)

### Copy CSS button
- New "Copy CSS" button next to "More" — generates ready-to-paste CSS for the active preset
- Icon-set-aware selectors:
  - Font Awesome: `i.{preset}.fa-solid, ...`
  - Tabler: `i.{preset}.ti`
  - SVG sets (Lucide, Heroicons, FluentUI): `svg.{preset}`
- Color-method aware: outputs `fill: currentColor` or `stroke: currentColor` based on each icon's actual color method
- Includes usage example for each framework (React, Vue, Svelte, plain HTML)
- CSS class name derived from preset key (e.g., "Neon Dark" → `neon-dark`)

### Tracking fixes
- Copy events now actually round-trip to the server (was JS-only, never written to `icon_metric`)
- Both modal copy buttons and grid/list hover-to-copy buttons track to DB now

### MCP server
- New `@keenmate/pure-admin-icons-mcp` package (`../pure-admin-icons-mcp`)
- 5 tools: `get_usage_guide`, `search_icons`, `get_icon_detail`, `get_icon_svg`, `list_icon_sets`

### llms.txt
- Rewritten to follow [llmstxt.org spec](https://llmstxt.org/) format

---

## 2026-04-08 — MCP server, llms.txt update ✅ PUBLISHED

### MCP server
- New `@keenmate/pure-admin-icons-mcp` package (separate repo at `../pure-admin-icons-mcp`)
- 5 tools: `get_usage_guide`, `search_icons`, `get_icon_detail`, `get_icon_svg`, `list_icon_sets`
- Multi-set support, format options (text/json/compact), Vue platform identifiers
- `get_usage_guide` tool (and `icons://docs` resource) returns the llms.txt content for AI clients

### llms.txt
- Rewritten to follow the [llmstxt.org spec](https://llmstxt.org/): H1 title, blockquote summary, bulleted markdown links
- Updated content: 16,000+ icons, 5 sets, all current API endpoints, color methods, MCP server reference
- Was: outdated FluentUI-only documentation

---

## 2026-04-07 — API endpoints, docs, footer, SEO

### API
- `GET /api/icons/:id` — single icon detail with full metadata (filenames, categories, phrases, svg_urls per size)
- `GET /api/icon-sets` — all icon sets with styles, sizes, license, `style_color_methods`, icon count
- `POST /api/maintenance/sync/:icon_set` — per-set sync (e.g., `fontawesome`, `fluentui`)
- Search response now includes `style_color_method` per icon
- Icon sets response includes `style_color_methods` jsonb map
- API docs page updated with all new endpoints, response fields, and examples

### Footer
- Proper 3-column footer: branding + icon count, resource links, icon sets with homepage links
- Bottom bar with license note and last sync time
- Sticky to viewport bottom when content is short

### SEO
- Updated meta tags: "16,000+ icons from 5 icon sets", Font Awesome and Vue mentioned
- Added keywords meta tag
- Dynamic page titles: search query in title (e.g., "calendar — Icon Search — icons.pureadmin.io")
- Page titles for all LiveViews (search, docs, discrepancies)
- Updated README with project overview, icon set table, API examples, stack info

### Fixes
- Discrepancies page now collects from all sync runs (was only showing latest, missing FluentUI's 783)
- Discrepancies page uses shared site nav and DaisyUI theme (was hardcoded light colors)
- Sync worker now stores full discrepancies list in `success_data` (was only storing count)
- Maintenance controller route added (was missing from router)
- Icon size slider hidden in grid mode (only relevant in list view)
- HEEx compilation error in API docs (JSON curly braces needed `phx-no-curly-interpolation`)
- Filename copy in grid/list hover buttons now applies the saved filename template from the detail modal (was copying raw filename only)

---

## 2026-04-07 19:50 — Font Awesome, dynamic filters, color method, UI polish ✅ PUBLISHED

### UI polish
- **Page loader** — full-screen themed loader while LiveView connects, prevents layout flash
- **Collapsible filters** — filters hidden behind a toggle button next to Grid/List; highlighted when active
- **Grid/List toggle** moved to search bar line with active state highlighting
- **Icon size slider** — adjustable icon preview size in list view (24–64px), persists to localStorage
- **Preview presets** — combined color+background presets in detail modal (Classic Light/Dark, Neon Dark, Blueprint, Warm, Transparent)
- **Responsive list view** — stacked cards on mobile, table on desktop
- **Icon set badge colors** — unique color per set across grid, list, active filters, and detail modal
- **Hover-to-copy on grid sizes** — hovering size badges shows platform copy buttons (same as list view)
- **Range slider** uses DaisyUI `range` component for dark theme visibility
- **Icon preview backgrounds** sync across grid, list, and detail modal from presets

### Bug fixes
- **Filter pruning** — switching icon sets now clears incompatible style/size selections (e.g., "filled" removed when switching from FluentUI to Font Awesome)
- **Filter persistence** — saved filters only restore on initial page load, not on every navigation (fixed loop bug)
- **SVG color replacement** — now handles `stroke`, `fill`, and `currentColor` (fixes invisible Lucide/Tabler outline icons)
- **db-gen template** — fixed hardcoded `FluentuiIcons.Repo` → `PureAdminIcons.Repo`

---

## 2026-04-07 19:50 — Font Awesome, dynamic filters, color method, UI improvements ✅ PUBLISHED

### Font Awesome Free
- New sync adapter downloading from npm registry (auto-fetches latest version)
- 3 styles: solid, regular, brands (~2855 icons after alias dedup)
- Platform identifiers for React (`@fortawesome/react-fontawesome`), Vue (`@fortawesome/vue-fontawesome`), Svelte (`svelte-fa`)
- Alias deduplication: `thumbtack`/`thumb-tack`, `eyedropper`/`eye-dropper`, etc. — identical SVGs, keep canonical name

### Dynamic filters
- Styles and sizes filters now adapt to selected icon sets (e.g., selecting Heroicons shows only outline/solid and 16/20/24)
- Filter order: Sets → Styles → Sizes (each on its own row)
- Filter selections persist to localStorage and restore on next visit
- Active filter badges match icon set colors; "Clear all" moved inline with active filters

### Color method
- New `style_color_method` from DB: `"fill"`, `"stroke"`, or `"multicolor"` per icon
- Detail modal shows CSS hint (`CSS: fill / color` or `CSS: stroke / color`)
- Multicolor icons hide the color picker with "not recolorable" message
- SVG color replacement now handles both `fill` and `stroke` attributes, including `currentColor`
- Icon previews use light background (`bg-white/80`) instead of theme-dependent recoloring

### UI improvements
- Grid/List toggle moved next to search bar with active state highlighting
- Icon set badges colored per set (FluentUI blue, Heroicons violet, Lucide orange, Tabler cyan, Font Awesome yellow)
- Set column added to list view
- List view: responsive cards on mobile, table on desktop
- Vue platform section added to icon detail modal (Lucide, Tabler, Heroicons, Font Awesome)
- All non-FluentUI identifiers include import statements
- Package names in section headers link to npmjs

### Tooling
- `make db-gen` command (cross-platform, uses `db-gen-win.exe` / `db-gen-linux`)
- db-gen files, templates, and config added to project

---

## 2026-04-07 19:50 — Mobile-responsive nav, spring time schedule ✅ PUBLISHED

### Added
- **Shared site navigation** — `Layouts.site_nav` component with consistent header across all pages (search, docs, API, MCP, LLMs)
- **Mobile burger menu** — hamburger toggle with dropdown nav on small screens
- **Cross-site link** — "Themes" link to pureadmin.io in the nav bar

### Changed
- **Unified navigation** — replaced per-page "Back to docs/search" headers with shared `site_nav` on all pages
- **Higher contrast search & filters** — search bar and filter checkboxes use `base-content` opacity borders instead of `base-300`, visible on dark themes (evening/night)
- **Spring time-of-day schedule** — adjusted theme transition times for longer daylight:
  - Morning: 5:00–9:00 (was 6:00–11:00)
  - Day: 9:00–20:00 (was 11:00–16:00)
  - Evening: 20:00–22:00 (was 16:00–20:00)
  - Night: 22:00–5:00 (was 20:00–6:00)

### Removed
- Per-page "Back to docs/search" link headers — replaced by unified nav

---

## 2026-04-07 19:50 — Icon-set-aware platform identifiers ✅ PUBLISHED

### Platform identifiers now match each icon library's actual conventions

Previously, the React and Svelte sections in the icon detail modal were hardcoded to FluentUI conventions. Now each icon set generates correct import statements and component syntax for its own packages.

- **React**: FluentUI (`@fluentui/react-icons`), Lucide (`lucide-react`), Tabler (`@tabler/icons-react`), Heroicons (`@heroicons/react`) — each with correct component naming and import paths
- **Vue** (new section): Lucide (`lucide-vue-next`), Tabler (`@tabler/icons-vue`), Heroicons (`@heroicons/vue`) — hidden for FluentUI (no official Vue package)
- **Svelte**: FluentUI (`svelte-fluentui`), Lucide (`lucide-svelte`), Tabler (`@tabler/icons-svelte`), Heroicons (`svelte-hero-icons`)
- All non-FluentUI identifiers now include the import statement alongside the component usage
- Package names in section headers link to npmjs (React, Vue) or project homepage (Svelte)
- Single identifier row for icon sets where the component name doesn't vary by size (avoids duplicate rows)
- "Include color" checkbox in Svelte section only shown for FluentUI (svelte-fluentui-specific feature)

## 2026-04-06 — Initial release

### New project: icons.pureadmin.io

Rebuilt from scratch as a Phoenix 1.8 project, replacing the old fluentui-icons Phoenix 1.7 codebase. Now shares the same visual stack as pureadmin.io.

### Stack

- Phoenix 1.8 + LiveView 1.1
- Tailwind CSS v4 + DaisyUI (same theme plugin as pureadmin.io)
- Heroicons v2.2.0 via Tailwind plugin
- Time-of-day theme system (4 themes: morning, day, evening, night)
- Same OKLCH color definitions as pureadmin.io

### Features ported from fluentui-icons

- Icon search with full-text + trigram + synonym matching
- Multi-icon-set support: FluentUI, Heroicons, Lucide, Tabler
- Grid and list view with lazy-loaded SVG previews
- Icon detail modal with platform identifiers (iOS, Android, React, Svelte, filename)
- Color picker for SVG preview customization
- Filename template system with placeholders
- Copy to clipboard for all identifiers
- Style, size, and icon set filters
- Pagination
- SVG file serving from local storage
- Daily sync from GitHub (Quantum scheduler, 3 AM)
- Dev icon cache (.cache/icons/) to avoid re-downloading
- API: /api/icons/search, /api/health
- Sync discrepancies page
- Plausible analytics

### Branding

- Logo: icons.**pure**admin.io (matching pureadmin.io pattern)
- Navbar with heroicon-decorated links (API, MCP, LLMs, Keenmate)
- Hero gradient section for search/filters
- Floating theme switcher (bottom-right)
- FOWT prevention (inline script in head)

### Icon color sync

- Color picker in icon detail modal persists to localStorage
- Grid/list icons apply saved color on load (fill replacement)
- Changing color in modal instantly updates all visible icons via `iconColorChanged` event
- Works across all icon sets (FluentUI, Tabler, Lucide, Heroicons)

### Performance

- SVG icon routes served outside the `:browser` pipeline (no session/CSRF/LiveView overhead)
- Lazy loading with IntersectionObserver + SVG caching

### Config

- DB credentials via `.local.exs` / `dev.local.exs` (gitignored), following dhl-location-factory pattern
- `config.exs` loads `.local.exs` and `{env}.local.exs` if they exist
- Production config via environment variables in runtime.exs (DB credentials required)
- Dockerfile with 7zip/unzip for icon sync
- Dev port: 4020

### Database

- `filenames` jsonb column added to icons table (maps size to actual filename)
- Eliminates per-icon-set filename computation — direct lookup from DB

# Changelog

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

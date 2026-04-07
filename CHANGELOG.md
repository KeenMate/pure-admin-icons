# Changelog

## 2026-04-07 — Mobile-responsive nav, spring time schedule

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

## 2026-04-07 — Icon-set-aware platform identifiers

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

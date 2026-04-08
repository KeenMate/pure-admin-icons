# icons.pureadmin.io

Search engine for open-source SVG icons. Aggregates multiple icon libraries into a single searchable catalog with platform-specific identifiers for iOS, Android, React, Vue, and Svelte.

**Live:** [icons.pureadmin.io](https://icons.pureadmin.io)

## Icon Sets

| Set | Icons | Styles | Sizes | License |
|-----|-------|--------|-------|---------|
| [FluentUI System Icons](https://github.com/microsoft/fluentui-system-icons) | ~5400 | regular, filled, color, light | 16, 20, 24, 28, 32, 48 | MIT |
| [Font Awesome Free](https://fontawesome.com/) | ~2850 | solid, regular, brands | 24 | CC BY 4.0 / MIT |
| [Heroicons](https://heroicons.com/) | ~650 | outline, solid | 16, 20, 24 | MIT |
| [Lucide](https://lucide.dev/) | ~1500 | regular | 24 | ISC |
| [Tabler Icons](https://tabler.io/icons) | ~5300 | outline, filled | 24 | MIT |

## API

All endpoints return JSON. No authentication required (except maintenance).

```bash
# Search icons
curl 'https://icons.pureadmin.io/api/icons/search?q=calendar&limit=5'

# Filter by icon set and style
curl 'https://icons.pureadmin.io/api/icons/search?q=arrow&set=heroicons&style=outline'

# Get icon detail
curl 'https://icons.pureadmin.io/api/icons/5403'

# List all icon sets
curl 'https://icons.pureadmin.io/api/icon-sets'

# Plain text format (token-efficient for AI)
curl 'https://icons.pureadmin.io/api/icons/search?q=pen&format=text'
```

**Endpoints:**
- `GET /api/icons/search` — search with filters (q, set, size, style, limit, format)
- `GET /api/icons/:id` — icon detail with filenames, identifiers, categories, phrases
- `GET /api/icon-sets` — all sets with styles, sizes, color methods, icon count
- `GET /api/health` — health check
- `GET /icons/:set/:style/:filename` — SVG file serving
- `POST /api/maintenance/:task` — sync, clean, cube (requires X-API-Key)
- `POST /api/maintenance/sync/:icon_set` — sync a specific icon set

**Docs:** [icons.pureadmin.io/docs/api](https://icons.pureadmin.io/docs/api) · [llms.txt](https://icons.pureadmin.io/llms.txt)

## MCP Server (for Claude Desktop / Claude Code)

```json
{
  "mcpServers": {
    "icons": {
      "command": "npx",
      "args": ["-y", "@keenmate/pure-admin-icons-mcp"]
    }
  }
}
```

Provides 5 tools: `get_usage_guide`, `search_icons`, `get_icon_detail`, `get_icon_svg`, `list_icon_sets`. Source: [`../pure-admin-icons-mcp`](../pure-admin-icons-mcp).

## Stack

- Phoenix 1.8 + LiveView 1.1
- Tailwind CSS v4 + DaisyUI
- PostgreSQL with full-text search + trigram matching
- Quantum scheduler (daily sync at 3 AM)
- Bandit HTTP server

## Development

```bash
mix setup              # Install deps, build assets
iex -S mix phx.server  # Start dev server at localhost:4020
mix test               # Run tests
mix format             # Format code
make db-gen            # Regenerate DB context from stored procedures
```

## Deployment

```bash
docker build -t pure-admin-icons:latest .
docker run -p 8888:8888 \
  -e SECRET_KEY_BASE=$(mix phx.gen.secret) \
  -e DB_USERNAME=... -e DB_PASSWORD=... \
  -e DB_HOSTNAME=... -e DB_DATABASE=pure_admin_icons \
  -e PHX_HOST=icons.pureadmin.io \
  pure-admin-icons:latest
```

## License

Application code: MIT. Icon SVGs retain their original licenses (see icon set table above).

Built by [KeenMate](https://keenmate.com).

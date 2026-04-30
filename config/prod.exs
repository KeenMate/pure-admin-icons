import Config

# We sit behind Traefik, which terminates TLS and only exposes the icons
# router on the `websecure` entrypoint. Plain HTTP cannot reach this app,
# so Phoenix `force_ssl` would only enforce something Traefik already
# enforces — and Traefik (in our setup) drops `X-Forwarded-Proto` on
# WebSocket Upgrade requests, which made `force_ssl` 301-loop the WS
# handshake. We use `Plug.RewriteOn` instead so Phoenix still trusts the
# proxy headers for URL generation but doesn't redirect.
config :pure_admin_icons, PureAdminIconsWeb.Endpoint,
  # Fingerprint static asset URLs via the digest manifest so deploys bust
  # browser caches automatically (each bundle gets a content-hashed URL,
  # so a rebuild = new URL = fresh fetch).
  cache_static_manifest: "priv/static/cache_manifest.json"

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.

defmodule PureAdminIconsWeb.API.DebugController do
  use PureAdminIconsWeb, :controller

  # Diagnostic endpoint that dumps the request as Phoenix sees it after the
  # reverse proxy. Use it to verify whether Traefik forwards the
  # `X-Forwarded-*` headers Phoenix needs for `force_ssl: rewrite_on`.
  def headers(conn, _params) do
    peer = Plug.Conn.get_peer_data(conn)
    remote_ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    peer_ip = peer.address |> :inet.ntoa() |> to_string()

    body = """
    method:        #{conn.method}
    request_path:  #{conn.request_path}
    query_string:  #{conn.query_string}
    scheme:        #{conn.scheme}
    host:          #{conn.host}
    port:          #{conn.port}
    remote_ip:     #{remote_ip}
    peer_address:  #{peer_ip}:#{peer.port}

    -- request headers (raw, as received) --
    #{conn.req_headers |> Enum.map_join("\n", fn {k, v} -> "#{k}: #{v}" end)}
    """

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, body)
  end
end

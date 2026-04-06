defmodule PureAdminIconsWeb.API.IconController do
  use PureAdminIconsWeb, :controller

  alias PureAdminIcons.Icons
  alias PureAdminIcons.Icons.Icon
  alias PureAdminIcons.SearchMetricsCollector

  @doc """
  Search for icons across all icon sets.

  ## Query Parameters
    * `q` - Search query (required)
    * `set` - Filter by icon set (optional, e.g., "fluentui", "lucide", "tabler", "heroicons")
    * `size` - Filter by size (optional, e.g., "24", "48")
    * `style` - Filter by style (optional, e.g., "regular", "filled", "outline", "solid")
    * `limit` - Max results (optional, default: 50, max: 100)
    * `format` - Response format (optional, default: "json")
      * "json" - Full response with all fields
      * "compact" - Minimal JSON with name, style, url
      * "text" - Plain text, one icon per line (most token-efficient for AI)

  ## Examples

      GET /api/icons/search?q=pen
      GET /api/icons/search?q=pen&set=fluentui
      GET /api/icons/search?q=pen&set=lucide&set=tabler
      GET /api/icons/search?q=calendar&style=regular&limit=20
      GET /api/icons/search?q=pen&format=text
  """
  def search(conn, params) do
    query = params["q"] || ""
    icon_sets = parse_icon_sets(params["set"])
    size = parse_size(params["size"])
    style = params["style"]
    limit = parse_limit(params["limit"])
    format = params["format"] || "json"

    # Build search options
    opts = [limit: limit]
    opts = if icon_sets != [], do: Keyword.put(opts, :icon_sets, icon_sets), else: opts
    opts = if size, do: Keyword.put(opts, :sizes, [size]), else: opts
    opts = if style, do: Keyword.put(opts, :styles, [style]), else: opts

    icons = case Icons.search(query, opts) do
      {:ok, results} -> results
      {:error, _} -> []
    end
    result_count = length(icons)

    # Record search metrics (batched, non-blocking) - include first icon_set if filtered
    icon_set_code = if icon_sets != [], do: hd(icon_sets), else: nil
    SearchMetricsCollector.record(query, size, style, result_count, icon_set_code)

    format_response(conn, format, %{query: query, icons: icons})
  end

  @doc """
  List all available icon sets with metadata.

  ## Examples

      GET /api/icon-sets
  """
  def icon_sets(conn, _params) do
    sets = Icons.list_icon_sets()
    json(conn, %{icon_sets: sets})
  end

  defp parse_icon_sets(nil), do: []
  defp parse_icon_sets(""), do: []
  defp parse_icon_sets(set) when is_binary(set), do: [set]
  defp parse_icon_sets(sets) when is_list(sets), do: sets

  defp parse_size(nil), do: nil
  defp parse_size(""), do: nil

  defp parse_size(s) do
    case Integer.parse(s) do
      {size, _} -> size
      :error -> nil
    end
  end

  defp parse_limit(nil), do: 50
  defp parse_limit(""), do: 50

  defp parse_limit(s) do
    case Integer.parse(s) do
      {limit, _} -> min(limit, 100)
      :error -> 50
    end
  end

  defp format_icon(icon) do
    %{
      id: icon.icon_id,
      icon_set: icon.icon_set_code,
      name: icon.name,
      style: icon.style_code,
      sizes: icon.sizes,
      ios: icon.ios_identifiers,
      android: icon.android_identifiers,
      svg_url: Icon.svg_url(icon, default_size(icon.sizes))
    }
  end

  defp default_size(sizes) when is_list(sizes) do
    # Prefer 24px if available, otherwise use the first size
    if 24 in sizes, do: 24, else: hd(sizes)
  end

  defp default_size(_), do: 24

  # Response formatters

  defp format_response(conn, "compact", %{query: query, icons: icons}) do
    json(conn, %{
      query: query,
      count: length(icons),
      results: Enum.map(icons, &format_icon_compact/1)
    })
  end

  defp format_response(conn, "text", %{icons: icons}) do
    text =
      icons
      |> Enum.map(&format_icon_text/1)
      |> Enum.join("\n")

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, text)
  end

  defp format_response(conn, _json, %{query: query, icons: icons}) do
    json(conn, %{
      query: query,
      count: length(icons),
      results: Enum.map(icons, &format_icon/1)
    })
  end

  defp format_icon_compact(icon) do
    %{
      icon_set: icon.icon_set_code,
      name: icon.name,
      style: icon.style_code,
      url: Icon.svg_url(icon, default_size(icon.sizes))
    }
  end

  defp format_icon_text(icon) do
    url = Icon.svg_url(icon, default_size(icon.sizes))
    "[#{icon.icon_set_code}] #{icon.name} → #{icon.style_code}: #{url}"
  end
end

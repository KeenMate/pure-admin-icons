defmodule PureAdminIconsWeb.API.DownloadController do
  @moduledoc """
  Explicit, tracked icon download endpoint for API consumers (MCP server,
  scripts, etc.).

  Unlike `/icons/:set/:style/:filename` which is a passive file serve used by
  browsers rendering `<img>` tags (untracked by design), hitting this endpoint
  is treated as an intentional download and recorded in `icon_metric` with
  `action=download`, `source=api`, `surface=direct`, `format=svg`.

  Resolves icon_id + size from the path, records the action, then delegates
  the actual SVG send to `IconFileController.show/2` so the file-serving logic
  (ETag, GitHub fallback, etc.) stays in one place.
  """
  use PureAdminIconsWeb, :controller

  require Logger

  alias PureAdminIcons.Icons
  alias PureAdminIcons.Repo
  alias PureAdminIconsWeb.IconFileController

  def show(conn, %{"icon_set" => icon_set, "style" => style, "filename" => filename} = params) do
    case resolve_icon(icon_set, style, filename) do
      {:ok, icon_id, size} ->
        case Icons.track_action(icon_id, "download", "api",
               size: size,
               surface: "direct",
               format: "svg"
             ) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.warning(
              "[api.download] track_action failed icon_id=#{icon_id}: #{inspect(reason)}"
            )
        end

      :not_found ->
        # Don't fail the download just because tracking can't resolve the row —
        # the user still gets their SVG (or 404 from IconFileController if it's
        # genuinely missing). Log so signature drift / orphaned files surface.
        Logger.info(
          "[api.download] icon not found for tracking: #{icon_set}/#{style}/#{filename}"
        )
    end

    IconFileController.show(conn, params)
  end

  # Looks up icon_id + size for a (set, style, filename) tuple.
  # `filenames` is jsonb shaped like %{"24" => "pencil-24.svg"} or
  # %{"0" => "scalable.svg"} for single-source icons. We unnest it via
  # jsonb_each_text and match on value so the size comes back too.
  defp resolve_icon(icon_set, style, filename) do
    sql = """
    SELECT i.icon_id, k.key::int AS size
    FROM public.icon i
    JOIN LATERAL jsonb_each_text(i.filenames) k(key, value) ON k.value = $3
    WHERE i.icon_set_code = $1
      AND i.style_code = $2
    LIMIT 1
    """

    case Repo.query(sql, [icon_set, style, filename]) do
      {:ok, %{rows: [[icon_id, size]]}} -> {:ok, icon_id, size}
      {:ok, %{rows: []}} -> :not_found
      {:error, reason} ->
        Logger.warning("[api.download] resolve_icon SQL failed: #{inspect(reason)}")
        :not_found
    end
  end
end

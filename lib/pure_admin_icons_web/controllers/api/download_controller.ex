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

  alias Database.DbContext
  alias PureAdminIcons.Icons
  alias PureAdminIconsWeb.IconFileController

  def show(conn, %{"icon_set" => icon_set, "style" => style, "filename" => filename} = params) do
    case DbContext.get_icon_by_filename(icon_set, style, filename) do
      {:ok, [%{icon_id: icon_id, size: size} | _]} ->
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

      {:ok, []} ->
        # No matching icon row — log so orphaned files / new icon sets surface,
        # but don't fail the request. IconFileController will still either serve
        # the file or 404 as appropriate.
        Logger.info(
          "[api.download] icon not found for tracking: #{icon_set}/#{style}/#{filename}"
        )

      {:error, reason} ->
        Logger.warning("[api.download] get_icon_by_filename failed: #{inspect(reason)}")
    end

    IconFileController.show(conn, params)
  end
end

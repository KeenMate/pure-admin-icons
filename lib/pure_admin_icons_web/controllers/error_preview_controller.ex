defmodule PureAdminIconsWeb.ErrorPreviewController do
  use PureAdminIconsWeb, :controller

  def show(conn, %{"code" => code}) do
    status = String.to_integer(code)

    conn
    |> put_status(status)
    |> put_root_layout(false)
    |> put_layout(false)
    |> put_view(PureAdminIconsWeb.ErrorHTML)
    |> render("#{status}.html")
  end
end

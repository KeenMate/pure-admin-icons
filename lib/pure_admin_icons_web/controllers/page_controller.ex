defmodule PureAdminIconsWeb.PageController do
  use PureAdminIconsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

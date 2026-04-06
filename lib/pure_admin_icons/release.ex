defmodule PureAdminIcons.Release do
  @moduledoc """
  Release tasks for production.

  Note: Database schema is now managed via debee.ps1 in icons-hub-database repo.
  Ecto migrations are no longer used.
  """

  @doc """
  No-op for backwards compatibility. Database migrations are managed externally.
  """
  def migrate do
    require Logger
    Logger.info("Database migrations are managed externally via debee.ps1 - skipping")
    :ok
  end
end

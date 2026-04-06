defmodule PureAdminIcons.Scheduler do
  @moduledoc """
  Quantum scheduler for running periodic tasks.

  Configured in config/config.exs to run daily icon sync at 3 AM.
  """
  use Quantum, otp_app: :pure_admin_icons
end

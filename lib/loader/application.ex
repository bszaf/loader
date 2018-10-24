defmodule Loader.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    :error_logger.info_msg("Starting loader ~n cookie: ~p", [Node.get_cookie()])
    children = [
      # Starts a worker by calling: Loader.Worker.start_link(arg)
      # {Loader.Worker, arg},
      {Loader.UserSup, []},
      {Loader.Controller, []},
      {Loader.DistController, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Loader.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

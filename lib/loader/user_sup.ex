defmodule Loader.UserSup do

  use DynamicSupervisor

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def add_user(opts) do
    spec =
      %{id: Loader.User,
        start: {Loader.User, :start_link, [opts]},
        restart: :temporary}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def del_user(user_pid) do
    DynamicSupervisor.terminate_child(__MODULE__, user_pid)
    :ok
  end

  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 1000)
  end

end

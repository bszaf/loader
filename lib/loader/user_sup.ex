defmodule Loader.UserSup do

  use DynamicSupervisor

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def add_user(opts) do
    spec = %{id: Loader.User , start: {Loader.User, :start_link, [opts]}}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

end

defmodule Loader.Controller do

  require Logger

  use GenServer

  @typep state :: %{
    scenario_module: Atom.t,
    total_users: Integer.t,
    interarrival: Integer.t,
    total_controllers: Integer.t,
    my_controller_id: Integer.t,
    apriori_scenario_state: any
  }

###
# API
###

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def load_scenario(opts) do
    GenServer.call(__MODULE__, {:load, opts})
  end

  def remote_load_scenario(node, opts) do
    GenServer.call({__MODULE__, node}, {:load, opts})
  end

  def add_users(n) do
    GenServer.call(__MODULE__, {:add_users, n})
  end

  def remote_add_users(node, n) do
    GenServer.call({__MODULE__, node}, {:add_users, n})
  end

###
# GenServer callbacks
###

  def init(_state) do
    initial_state = %{
      scenario_module: nil,
      total_users: 0,
      interarrival: 10,
      total_controllers: 1,
      my_controller_id: 1}
    {:ok, initial_state}
  end

  def handle_call({:load, _}, _from, %{scenario_module: m} = s) when m != nil do
    reply = {:error, :already_loaded}
    {:reply, reply, s}
  end

  def handle_call({:load, opts}, _from, state) do
    with :ok <- check_scenario_opts(opts),
         :ok <- check_if_scenario_available(opts),
         {:ok, apriori_scenario_state} <- init_scenario(opts)
    do
      reply = {:ok, :loaded}
      state = Map.put(state, :apriori_scenario_state, apriori_scenario_state)
              |> Map.merge(opts)
      {:reply, reply, state}
    else
      err ->
        {:reply, err, state}
    end
  end

  def handle_call({:add_users, _n}, _from, %{scenario_module: m} = s) when m == nil do
    reply = {:error, :not_started}
    {:reply, reply, s}
  end
  def handle_call({:add_users, n}, from, state) do
    GenServer.reply(from, {:ok, :adding})
    {:ok, state} = add_users(state, n)
    {:noreply, state}
  end

  def handle_call(_request, _from, state) do
    reply = {:error, :unknown}
    {:reply, reply, state}
  end

###
# Helpers
###

  defp check_if_scenario_available(%{scenario_module: module}) do
    if Code.ensure_loaded?(module) do
      :ok
    else
      {:error, :scenario_unavailable}
    end
  end
  defp check_if_scenario_available(_), do: {:error, :scenario_not_specified}

  defp init_scenario(%{scenario_module: module}) do
    try do
      {:ok, _state} = module.pre_init()
    catch
      error -> {:error, error}
    end
  end

  @spec add_users(state(), Integer.t) :: :ok
  defp add_users(%{scenario_module: m,
    total_users: total_users,
    interarrival: interarrival,
    total_controllers: total_controllers,
    apriori_scenario_state: scenario_state,
    my_controller_id: id} = state,
    n)
  do
    start_id = total_users + 1
    end_id = total_users + n
    my_ids = my_ids([start: start_id, end: end_id], total_controllers, id)

    Logger.info("Starting #{length(my_ids)} users")
    Enum.each(my_ids,
              fn user_id ->
                user_opts = %{
                  total_users: n,
                  aprior_state: scenario_state,
                  scenario_module: m,
                  id: user_id}
                Loader.UserSup.add_user(user_opts)
                Process.sleep(interarrival)
              end)
    {:ok, %{state | total_users: end_id}}
  end

  def my_ids([start: s, end: e], modulo, my_id) do
    for x <- s..e,
        rem(x, modulo) + 1 == my_id,
      do: x
  end

  #TODO
  defp check_scenario_opts(_opts) do
    :ok
  end

  @spec check_keys(Map.t, [keys :: any]) :: :ok | {:error, [keys :: any]}
  defp check_keys(map, keys) do
    map_keys = Map.keys(map)
    case Enum.filter(keys, &(&1 not in map_keys)) do
      [] -> :ok
      missing -> {:error, missing}
    end
  end

end

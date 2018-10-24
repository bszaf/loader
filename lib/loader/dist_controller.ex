defmodule Loader.DistController do

  require Logger

  use GenServer

  @typep node_definition :: {node(), Integer.t()} | {node(), Binary.t(), Integer.t()}
  @typep state :: %{
    nodes: [node()],
    retry_cluster: boolean(),
    to_cluster_with: node()
  }

  @default_config [
    retry_cluster: true
  ]

  def start_link(_args), do:
    GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def load_scenario(opts), do: GenServer.call(__MODULE__, {:load, opts})

  def add_users(n), do: GenServer.call(__MODULE__, {:add_users, n})

###
# GenServer callbacks
###

  def init(_state) do
    :net_kernel.monitor_nodes(true)
    module_config = Loader.Config.get_app_env(__MODULE__, [])
    module_config = Keyword.merge(@default_config, module_config)
    retry = Keyword.get(module_config, :retry_cluster)
    to_cluster = get_node_to_cluster()
    initial_state =
      %{nodes: :erlang.nodes(),
        retry_cluster?: retry,
        to_cluster: to_cluster}
    send(self(), :try_cluster)
    {:ok, initial_state}
  end

  def handle_call({:load, opts}, _from, %{nodes: nodes} = state) do
    me_and_others = [node() | nodes]
    {_ok, not_ok} =
    load_on_all(me_and_others, opts)
    |> Enum.split_with(&(&1 == {:ok, :loaded}))
    reply = case not_ok do
      [] ->
        {:ok, :loaded}
      not_ok ->
        {:error, not_ok}
    end
    {:reply, reply, state}
  end

  def handle_call({:add_users, opts}, _from, %{nodes: nodes} = state) do
    me_and_others = [node() | nodes]
    {_ok, not_ok} =
    add_users_on_all(me_and_others, opts)
    |> Enum.split_with(&(&1 == {:ok, :loaded}))
    reply = case not_ok do
      [] ->
        {:ok, :started}
      not_ok ->
        {:error, not_ok}
    end
    {:reply, reply, state}
  end

  # no one to cluster with, ignoring
  def handle_info(:try_cluster, %{to_cluster: nil} = s), do: {:noreply, s}
  def handle_info(:try_cluster, %{to_cluster: node, retry_cluster?: r} = s) do
    if not :net_kernel.connect_node(node) do
        r and Process.send_after(self(), :try_cluster, 10_000)
    end
    {:noreply, s}
  end

  def handle_info({:nodeup, node}, %{nodes: nodes} = state) do
    case node in nodes do
      true ->
        {:noreply, state}
      false ->
        Logger.info("Clustered with #{inspect node}")
        {:noreply, %{state | nodes: [node | nodes]}}
    end
  end

  def handle_info({:nodedown, node}, %{nodes: nodes} = state) do
    case node not in nodes do
      true ->
        {:noreply, state}
      false ->
        Logger.info("Connection lost with node: #{inspect node}")
        {:noreply, %{state | nodes: nodes -- [node]}}
    end
  end

  ###
  # Helpers
  ###

  @spec get_node_to_cluster() :: node_definition | nil
  defp get_node_to_cluster() do
    case Loader.Config.get(:cluster_with) do
      node when is_atom(node) ->
        node
      _ ->
        nil
    end
  end

  defp add_users_on_all(nodes, n) do
    Enum.map(nodes, &(add_users(&1, n)))
  end

  defp add_users(node, n) do
    start_fun =
      if node == node() do
          fn -> Loader.Controller.add_users(n) end
      else
          fn -> Loader.Controller.remote_add_users(node, n) end
      end
    call_catch_timeout(start_fun)
  end

  defp load_on_all(nodes, opts) do
    opts = Map.put(opts, :total_controllers, length(nodes))
    acc = {1, []}
    {_, result} = Enum.reduce(nodes, acc, &(load_reducer(&1, &2, opts)))
    result
  end

  defp load_reducer(node, {node_id, previous_results}, opts) do
    opts = Map.put(opts, :my_controller_id, node_id)
    load_fun = fn -> Loader.Controller.remote_load_scenario(node, opts) end
    result = call_catch_timeout(load_fun)
    {node_id + 1, [result | previous_results]}
  end

  defp call_catch_timeout(fun) do
    try do
      fun.()
    catch
      :exit, {:timeout, _} = t -> {:error, t}
    end
  end

end

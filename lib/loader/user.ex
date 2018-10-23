defmodule Loader.User do

  require Logger

  def start_link(opts) do
    opts = Enum.into(opts, %{})
    true = Map.has_key?(opts, :scenario_module)
    true = Map.has_key?(opts, :id)

    :proc_lib.start_link(__MODULE__, :init, [Map.put(opts, :parent, self())])
end

  def init(%{parent: parent_pid, scenario_module: m} = opts) do
    :proc_lib.init_ack(parent_pid, {:ok, self()})
    state = Map.get(opts, :apriori_state, %{})
    case m.init(state) do
      {:ok, state} ->
        loop(m, state)
      {:error, reason} ->
        exit(reason)
    end
  end

  defp loop(m, state) do
    case safely_apply(&m.receive_do/1, state) do
      {:ok, :stop} ->
        stop()
      {:ok, state} -> loop(m, state)
      {:error, _} = err -> exit(err)
    end
  end

  defp safely_apply(fun, state) do
    try do
      fun.(state)
    catch
      error -> {:error, error}
    end
  end

  defp stop(), do: {:shutdown, :normal}

end

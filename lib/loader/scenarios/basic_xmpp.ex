defmodule Loader.Scenario.BasicXMPP do

  use Loader.ReactiveScenario

  alias Loader.Metrics

  require Logger

  rule match: :start_connection, handler: handle_start_connection
  rule match: :stop_connection, handler: handle_stop_connection
  rule match: :send_message, handler: handle_send_message
  rule match: {:stanza, _, {:xmlel, "message", _, _}, _}, handler: handle_message


  # called once before scenario is started
  def pre_init() do
    :ok = Metrics.init_metric([:times, :connection], :histogram)
    :ok = Metrics.init_metric([:counters, :connection, :failures], :spiral)
    :ok = Metrics.init_metric([:counters, :messages, :sent], :spiral)
    :ok = Metrics.init_metric([:counters, :messages, :received], :spiral)
    :ok = Metrics.init_metric([:times, :ttd, :local], :histogram)
    :ok = Metrics.init_metric([:times, :ttd, :global], :histogram)
    state = %{}
    {:ok, state}
  end

  # called for each user
  def init(state) do
    #send(self(), :start_connection)
    schedule(:start_connection, in: :rand.uniform(20_000))
    state = Map.put(state, :disconnect_after, 10_000)
    state = Map.put(state, :reconnect_after, 10_000)
    state = Map.put(state, :dc, random_dc())
    {:ok, state}
  end

  def handle_start_connection(_msg, state) do
    cfg = make_user(state)
    {connection_time, connection_result} = :timer.tc(:escalus_connection, :start, [cfg])
    case connection_result do
      {:ok, client, _} ->
        Metrics.report_histogram([:times, :connection], connection_time)
        state = Map.put(state, :client, client)
        pres = :escalus_stanza.presence(<<"available">>)
        :escalus_connection.send(client, pres)
        #schedule(:stop_connection, in: state.disconnect_after)
        schedule(:send_message, in: 120_000)
        {:ok, state}
      error ->
        Logger.error("Error, #{inspect error}")
        Metrics.report_spiral([:counters, :connection, :failures])
        state = Map.update(state, :connection_failures, 0, fn x -> x + 1 end)
        retry_timeout = backoff(state.connection_failures)
        schedule(:start_connection, in: retry_timeout)
        {:ok, state}
    end
  end

  def handle_stop_connection(_msg, %{client: client} = state) do
    :escalus_connection.stop(client)
    state = Map.delete(state, :client)
    schedule(:start_connection, in: state.reconnect_after)
    {:ok, state}
  end

  def handle_send_message(_msg, %{client: client, id: my_id} = state) do
    id =
      case my_id do
        1 -> 2
        n -> n - 1
      end
    jid = make_jid(id)
    msg = make_message(jid, state)
    res = :escalus_connection.send(client, msg)

    # Logger.warn("Send message to #{jid}, result: #{res}")
    Metrics.report_spiral([:counters, :messages, :sent])
    mean = Loader.Config.get(:send_message_delay_mean, 10)
    var = Loader.Config.get(:send_message_delay_var, 5)
    delay = :rand.normal(mean, var) * 1000
    delay = round(delay)
    schedule(:send_message, in: delay)
    {:ok, state}
  end
  # ignore sending message, when not connected - client not in state:
  def handle_send_message(_msg, state), do: {:ok, state}

  def handle_message({:stanza, _pid, stanza, metadata}, %{dc: dc} = state) do
    recv_ts = Map.get(metadata, :recv_timestamp)
    {{send_ts, from_dc}, _} =
      stanza
      |> :exml_query.path(element: "body")
      |> :exml_query.cdata()
      |> Code.eval_string()
    ttd = recv_ts - send_ts
    #Logger.warn("#{inspect {send_ts, from_dc}} my_dc: #{dc}")
    case from_dc do
      ^dc ->
        Metrics.report_histogram([:times, :ttd, :local], ttd)
      _ ->
        Metrics.report_histogram([:times, :ttd, :global], ttd)
    end
    Metrics.report_spiral([:counters, :messages, :received])
    {:ok, state}
  end

  def handle_info(msg, state) do
    # Logger.warn "Got unhandled message #{inspect msg}"
    {:ok, state}
  end
  # Helpers

  defp backoff(n), do: :timer.seconds(n * n)

  defp schedule(msg, in: timeout), do:
    :erlang.send_after(timeout, self(), msg)

  def make_user(%{id: n, dc: dc}) do
    [
      username: "user_#{n}",
      password: "password_#{n}",
      stream_management: false,
      carbons: false,
      resource: "res_#{n}",
      server: "localhost",
      host: "10.100.0.140",
      port: dc_port(dc)
    ]
  end

  defp dc_port(:eu), do: Loader.Config.get(:eu_port, 5222)
  defp dc_port(:us), do: Loader.Config.get(:us_port, 5223)

  defp random_dc do
    case :rand.uniform() < 0.45 do
      true ->
        :eu
      _ ->
        :us
    end
  end

  defp make_jid(id), do: "user_#{id}@localhost"

  defp make_message(jid, %{dc: dc}) do
    msg = inspect({:os.system_time(:micro_seconds), dc})
    id = :escalus_stanza.id()
    :escalus_stanza.set_id(:escalus_stanza.chat_to(jid, msg), id)
  end

end

defmodule Loader.Scenario.SimpleBlogPost do

  use Loader.ReactiveScenario

  alias Loader.Metrics

  require Logger

  # Inside events
  rule match: :register, handler: handle_register
  rule match: :login, handler: handle_login

  rule match: :do_action, handler: handle_action
  rule match: :publish_post, handler: handle_publish_post
  rule match: :get_users, handler: handle_get_users
  rule match: :get_user_posts, handler: handle_get_user_posts
  rule match: :publish_comment, handler: handle_publish_comment

  # Outisde events
  rule match: %HTTPoison.AsyncStatus{}, handler: handle_status
  rule match: %HTTPoison.AsyncHeaders{}, handler: handle_headers
  rule match: %HTTPoison.AsyncChunk{}, handler: handle_chunk
  rule match: %HTTPoison.AsyncEnd{}, handler: handle_end

  # called once before scenario is started
  def pre_init() do
    # register state metrics
    :ok = Metrics.init_metric([:times, :register], :histogram)
    :ok = Metrics.init_metric([:counters, :register, :failure], :spiral)
    :ok = Metrics.init_metric([:counters, :register, :success], :spiral)

    # login state metrics
    :ok = Metrics.init_metric([:times, :login], :histogram)
    :ok = Metrics.init_metric([:counters, :login, :failure], :spiral)
    :ok = Metrics.init_metric([:counters, :login, :success], :spiral)

    # publish post metrics
    :ok = Metrics.init_metric([:times, :publish_post], :histogram)
    :ok = Metrics.init_metric([:counters, :publish_post, :failure], :spiral)
    :ok = Metrics.init_metric([:counters, :publish_post, :success], :spiral)

    # get users metrics
    :ok = Metrics.init_metric([:times, :get_users], :histogram)
    :ok = Metrics.init_metric([:counters, :get_users, :failure], :spiral)
    :ok = Metrics.init_metric([:counters, :get_users, :success], :spiral)

    # get user posts metrics
    :ok = Metrics.init_metric([:times, :get_user_posts], :histogram)
    :ok = Metrics.init_metric([:counters, :get_user_posts, :failure], :spiral)
    :ok = Metrics.init_metric([:counters, :get_user_posts, :success], :spiral)

    # publish comment metrics
    :ok = Metrics.init_metric([:times, :publish_comment], :histogram)
    :ok = Metrics.init_metric([:counters, :publish_comment, :failure], :spiral)
    :ok = Metrics.init_metric([:counters, :publish_comment, :success], :spiral)

    url = Loader.Config.get(:api_url)
    state = %{url: url}
    {:ok, state}
  end

  # called for each user
  def init(state) do
    schedule(:register, in: 0)
    #schedule(:start_connection, in: :rand.uniform(20_000))
    new_state =
      state
      |> Map.put(:actions, %{})
      |> Map.put(:state, :register)
    {:ok, new_state}
  end

  # Internal event handlers

  def handle_register(_, %{url: url, id: id} = state) do
    %{email: "user_#{id}@localhost", password: "password_#{id}"}
    |> Poison.encode!()
    |> async_http_post("#{url}/register")
    |> case do
      {:ok, %{id: request_id}} ->
        action = %{action: :register, start_ts: :os.system_time()}
        new_state = Map.update!(state, :actions, &(Map.put(&1, request_id, action)))
        {:ok, new_state}
      {:error, _} ->
        delay = :rand.uniform(10_000) + 1_000
        Metrics.report_spiral([:counters, :register, :failure])
        schedule(:register, in: delay)
        {:ok, state}
    end
  end

  def handle_login(_, %{url: url, id: id} = state) do
    Logger.warn "Loging in my_id: #{id}"
    %{email: "user_#{id}@localhost", password: "password_#{id}"}
    |> Poison.encode!()
    |> async_http_post("#{url}/login")
    |> case do
      {:ok, %{id: request_id}} ->
        action = %{action: :login, start_ts: :os.system_time()}
        new_state = append_action(state, request_id, action)
        {:ok, new_state}
      {:error, _} ->
        delay = :rand.uniform(10_000) + 1_000
        Metrics.report_spiral([:counters, :login, :failure])
        schedule(:login, in: delay)
        {:ok, state}
    end
  end

  def handle_action(_, state) do
    action = Enum.random([:publish_post, :get_users, :get_user_posts, :publish_comment])
    delay = :rand.uniform(5_000) + 1_000 # 1s - 6s
    schedule(action, in: delay)
    {:ok, state}
  end

  def handle_publish_post(_, %{url: url} = state) do
    Logger.debug("handling post publish")
    %{body: "This is my very new blog post"}
    |> Poison.encode!()
    |> async_http_post("#{url}/users/#{state.user_id}/posts", state.token)
    |> case do
      {:ok, %{id: request_id}} ->
        action = %{action: :publish_post, start_ts: :os.system_time()}
        new_state = append_action(state, request_id, action)
        {:ok, new_state}
      {:error, _} ->
        delay = :rand.uniform(10_000) + 1_000
        Metrics.report_spiral([:counters, :publish_post, :failure])
        schedule(:do_action, in: delay)
        {:ok, state}
    end
  end

  def handle_get_users(_, %{url: url} = state) do
    Logger.debug("handling get users")
    case async_http_get("#{url}/users", state.token) do
      {:ok, %{id: request_id}} ->
        action = %{action: :get_users, start_ts: :os.system_time()}
        new_state = append_action(state, request_id, action)
        {:ok, new_state}
      {:error, _} ->
        delay = :rand.uniform(10_000) + 1_000
        Metrics.report_spiral([:counters, :get_users, :failure])
        schedule(:do_action, in: delay)
        {:ok, state}
    end
  end

  def handle_get_user_posts(_, %{url: url, user_to_comment: id} = state) do
    Logger.debug("handling get user posts")
    case async_http_get("#{url}/users/#{id}/posts", state.token) do
      {:ok, %{id: request_id}} ->
        action = %{action: :get_user_posts, start_ts: :os.system_time()}
        new_state = append_action(state, request_id, action)
        {:ok, new_state}
      {:error, _} ->
        delay = :rand.uniform(10_000) + 1_000
        Metrics.report_spiral([:counters, :get_user_posts, :failure])
        schedule(:do_action, in: delay)
        {:ok, state}
    end
  end

  def handle_get_user_posts(_, state) do
    # fallback = no user was choosen to retrieve posts
    schedule(:do_action, in: 0)
    {:ok, state}
  end

  def handle_publish_comment(_, %{url: url,
    user_to_comment: user_id,
    post_to_comment: post_id} = state)
  do
    Logger.debug("handling publish comment")
    %{body: "I like your post!"}
    |> Poison.encode!()
    |> async_http_post("#{url}/users/#{user_id}/posts/#{post_id}/comments", state.token)
    |> case do
      {:ok, %{id: request_id}} ->
        action = %{action: :publish_comment, start_ts: :os.system_time()}
        new_state = append_action(state, request_id, action)
        {:ok, new_state}
      {:error, _} ->
        delay = :rand.uniform(10_000) + 1_000
        Metrics.report_spiral([:counters, :publish_comment, :failure])
        schedule(:do_action, in: delay)
        {:ok, state}
    end
  end

  def handle_publish_comment(_, state) do
    # fallback = no user and/or post was choosen to comment
    Logger.debug("handling publish comment, but no post to comment")
    schedule(:do_action, in: 0)
    {:ok, state}
  end

  ## HTTP events

  ## This function is called, when HTTP status arrives
  def handle_status(%{code: 200, id: req_id}, %{actions: actions} = state)
  do
    ts = :os.system_time()
    %{action: action, start_ts: start_ts} = Map.get(actions, req_id)
    Logger.debug("status handling action: #{action}")
    Metrics.report_histogram([:times, action], ts - start_ts)
    Metrics.report_spiral([:counters, action, :success])
    {:ok, state}
  end

  ## This clause handles 400 codes, when HTTP status arrives
  def handle_status(%{code: code, id: req_id}, %{actions: actions} = state)
  when code >= 400
  do
    %{action: action} = Map.get(actions, req_id)
    Metrics.report_spiral([:counters, action, :failure])
    new_state = Map.put(state, :state, {:retry, state, in: 5_000})
    {:ok, new_state}
  end

  def handle_headers(_, state) do
    #Logger.debug("handle headers")
    {:ok, state}
  end

  def handle_chunk(%{id: req_id, chunk: body}, %{actions: actions} = state) do
    action =
      Map.get(actions, req_id)
      |> Map.update(:buffer, [body], &([body|&1]))
    actions = Map.put(actions, req_id, action)
    new_state = Map.put(state, :actions, actions)
    {:ok, new_state}
  end

  def handle_end(%{id: req_id}, %{actions: actions, state: current_state} = state) do
    %{action: action, buffer: buffer} = Map.get(actions, req_id)
    ## Process response from server
    resp = Poison.decode!(Enum.reverse(buffer))
    state =
      case action do
        :login ->
          Map.put(state, :token, resp["token"])
        :register ->
          Map.put(state, :user_id, resp["user_id"])
        :get_users ->
          save_user_to_comment_post(resp["users"], state)
        :get_user_posts ->
          save_post_to_comment(resp["posts"], state)
        _ ->
          state
      end
    # decide on further actions
    {next_state, delay} =
      case current_state do
        {:retry, state, in: delay} -> {state, delay}
        :register ->
          {:login, 0}
        :login ->
          {:do_action, 0}
        _ ->
          {:do_action, 0}
      end
    new_actions = Map.delete(actions, req_id)
    new_state =
      Map.put(state, :actions, new_actions)
      |> Map.put(:state, next_state)
    schedule(next_state, in: delay)
    :erlang.garbage_collect()
    {:ok, new_state}
  end

  def handle_info(_msg, state) do
    # Logger.warn "Got unhandled message #{inspect msg}"
    {:ok, state}
  end

  ## HTTP request helpers

  defp async_http_post(body, url, token \\ nil) do
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{token}"}
    ]
    HTTPoison.post(url,
      body,
      headers,
      [
        stream_to: self(),
        timeout: 60_000,
        recv_timeout: 60_000
      ])
  end

  defp async_http_get(url, token) do
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{token}"}
    ]
    HTTPoison.get(url,
      headers,
      [
        stream_to: self(),
        timeout: 60_000,
        recv_timeout: 60_000
      ])
  end

  # Helpers

  defp append_action(state, req_id, action), do: Map.update!(state, :actions, &(Map.put(&1, req_id, action)))

  defp save_user_to_comment_post(users, state) do
    case users do
      [] ->
        state
      _ ->
        Map.put(state, :user_to_comment, Enum.random(users)["id"])
    end
  end

  defp save_post_to_comment(posts, state) do
    case posts do
      [] ->
        state
      _ ->
        Map.put(state, :post_to_comment, Enum.random(posts)["id"])
    end
  end

  defp backoff(n), do: :timer.seconds(n * n)

  defp schedule(msg, in: timeout), do:
    :erlang.send_after(timeout, self(), msg)

end

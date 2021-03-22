defmodule Loadex.Worker do
  @moduledoc """
  Each user corresponds to a Worker in Loadex.
  The worker is initialized with a list of HTTP requests that are sent periodically in a worker process.
  The selection of next request and result handling is managed via handle_info callbacks.
  """
  use GenServer

  require Logger

  @stats_min_duration Application.get_env(:loadex, :stats_min_duration, 10000)

  @doc "Start Worker."
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @doc "Initialize worker state based on configuration: sleep time and list of requests."
  @impl GenServer
  def init(%{sleep_time: sleep_time, requests: requests}) do
    # TODO: get config
    # TODO: create connection
    Loadex.Stats.register_worker()
    # TODO: notify stat on running clients
    Loadex.Runner.on_worker_started(__MODULE__, self())
    # configure list of requests
    send(self(), :loop)

    {:ok,
     %{
       sleep_time: sleep_time,
       stats_last_ms: Loadex.Stats.now(),
       stats_reqs: 0,
       stats_entries: 0,
       stats_errors: 0,
       verify_percent: 3,
       requests: requests,
       next_request: 0
     }}
  end

  @impl GenServer
  def handle_info(:loop, state) do
    loop(state)
  end

  def handle_info(:stop, state) do
    # close connection
    {:stop, :normal, state}
  end

  ### Entry point of request loop. Increases the number of sent requests for stats, sends request to the server,
  ### handles result of message sending and schedules next request."
  defp loop(state) do
    state = maybe_send_stats(state)
    # increase stats_reqs in state
    state = %{state | stats_reqs: state.stats_reqs + 1}
    Process.send_after(self(), :loop, state.sleep_time)
    {res, state} = send_request(state)
    state = handle_result(res, state)
    {:noreply, state}
  end

  defp send_request(%{next_request: next_request, requests: requests} = state) do
    request = Enum.at(requests, next_request)

    params =
      case Map.get(request, :body) do
        nil ->
          [method: request.method, url: request.url, headers: request.headers]

        body ->
          [method: request.method, url: request.url, headers: request.headers, body: body]
      end

    res = Tesla.request(params)
    {res, %{state | next_request: rem(next_request + 1, length(requests))}}
  end

  defp handle_result({:ok, %{status: status}}, state) when div(status, 100) == 2 do
    %{state | stats_entries: state.stats_entries + 1}
  end

  defp handle_result({:ok, %{status: status}}, state) do
    Logger.error("Error (#{inspect(self())}) #{status}")
    %{state | stats_errors: state.stats_errors + 1}
  end

  defp handle_result({:error, reason}, state) do
    Logger.error("Error (#{inspect(self())}) #{inspect(reason)}")
    %{state | stats_errors: state.stats_errors + 1}
  end

  defp maybe_send_stats(
         %{stats_last_ms: last, stats_entries: entries, stats_errors: errors, stats_reqs: reqs} =
           state
       ) do
    now_ms = Loadex.Stats.now()
    duration_ms = Loadex.Stats.diff(now_ms, last)

    case duration_ms > @stats_min_duration do
      false ->
        state

      true ->
        Loadex.Stats.update_stats(%{
          req_count: reqs,
          entry_count: entries,
          error_count: errors,
          duration_since_last_update: duration_ms
        })

        %{state | stats_last_ms: now_ms, stats_entries: 0, stats_errors: 0, stats_reqs: 0}
    end
  end
end

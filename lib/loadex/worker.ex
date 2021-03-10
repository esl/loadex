defmodule Loadex.Worker do
  use GenServer

  @periodic_stats_min_duration_ms 1000

  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  def init(%{sleep_time: sleep_time}) do
    # TODO: get config
    # TODO: create connection
    Loadex.Stats.register_worker()
    # TODO: notify stat on running clients
    Loadex.Runner.on_worker_started(__MODULE__, self())
    send(self(), :loop) # configure list of requests
    {:ok, %{sleep_time: sleep_time,
            stats_last_ms: Loadex.Stats.now(),
            stats_reqs: 0,
            stats_entries: 0,
            stats_errors: 0,
            verify_percent: 3}}
  end

  def handle_info(:loop, state) do
    loop(state)
  end

  def handle_info(:stop, state) do
    # close connection
    {:stop, :normal, state}
  end

  defp loop(state) do
    state = maybe_send_stats(state)
    # increase stats_reqs in state
    state = %{state | stats_reqs: state.stats_reqs + 1}
    res = send_request(state)
    handle_result(res, state)
  end

  defp handle_result(_res, state) do
    Process.send_after(self(), :loop, state.sleep_time)
    {:noreply, state} # update entries or errors
  end

  defp send_request(_state) do
    200 # TODO: HTTP result
  end

  defp maybe_send_stats(%{stats_last_ms: last,
                          stats_entries: entries,
                          stats_errors: errors,
                          stats_reqs: reqs} = state) do
    now_ms = Loadex.Stats.now()
    duration_ms = Loadex.Stats.diff(now_ms, last)
    case duration_ms > @periodic_stats_min_duration_ms do
      false ->
        state
      true ->
        Loadex.Stats.update_stats(%{req_count: reqs,
                                    entry_count: entries,
                                    error_count: errors,
                                    duration_since_last_update: duration_ms})
        %{state | stats_last_ms: now_ms, stats_entries: 0, stats_errors: 0, stats_reqs: 0}
    end
  end
end

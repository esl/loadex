defmodule Loadex.Runner do
  use GenServer

  require Logger

  @default_max_sleep_time_ms 200
  @default_verification_percent 3
  @workers_tab :loadex_workers

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def stop() do
    GenServer.call(__MODULE__, :stop)
  end

  def print_stats() do
    %{request_rate: req_rate,
      entry_rate: entry_rate,
      error_rate: error_rate,
      error_pct: error_percent} = Loadex.Stats.get_stats()
    # TODO check verification stats
    Logger.info("Req=#{req_rate}/s Submitted=#{entry_rate}/s Err=#{error_rate}/s (#{error_percent}%)")
  end

  def add(number_of_users) when is_integer(number_of_users) and number_of_users > 0 do
    GenServer.call(__MODULE__, {:add_users, number_of_users})
  end

  def add(_) do
    :invalid_input
  end

  def remove(count) when is_integer(count) and count > 0 do
    workers = :ets.tab2list(@workers_tab)
    stop_users(count, workers)
  end

  def remove(_) do
    :invalid_input
  end

  def on_worker_started(module, pid) do
    Logger.info("Started worker=#{inspect(module)} pid=#{inspect(pid)}")
    :ets.insert(@workers_tab, {pid})
  end

  def on_worker_terminated(module, pid) do
    Logger.info("Terminated worker=#{inspect(module)} pid=#{inspect(pid)}")
    :ets.delete(@workers_tab, pid)
  end

  def init(%{workers: workers, requests: requests}) do
    Process.flag(:trap_exit, :true)
    Loadex.Stats.init()
    :ets.new(@workers_tab, [:named_table, :public, :bag])
    state = %{sleep_ms: @default_max_sleep_time_ms, verify_percent: @default_verification_percent, requests: requests}
    Enum.each(1..workers, fn _ -> create_worker(state) end)
    :timer.apply_interval(10000, __MODULE__, :print_stats, [])
    # TODO: get values from app config
    {:ok, state}
  end

  def handle_call({:add_users, number_of_users}, _from, state) do
    Enum.each(1..number_of_users, fn _ -> create_worker(state) end)
    {:reply, :ok, state}
  end

  def handle_call(:stop, _from, state) do
    :ets.tab2list(@workers_tab)
    |> Enum.each(fn {pid} ->
      send(pid, :stop)
      :ets.delete(@workers_tab, pid)
    end)
    {:stop, :normal, state}
  end

  def handle_call(_, _, state) do
    {:reply, :ok, state}
  end

  def handle_info({:EXIT, pid, _reason}, state) do
    Process.unlink(pid)
    on_worker_terminated(:unknown, pid)
    {:noreply, state}
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  defp create_worker(%{sleep_ms: sleep_ms, requests: requests}) do
    # TODO: supervisor
    {:ok, pid} = Loadex.Worker.start_link(%{sleep_time: sleep_ms, requests: requests})
    Process.link(pid)
  end

  defp stop_users(count, [{pid} | workers]) when count > 0 do
    send(pid, :stop)
    stop_users(count - 1, workers)
  end

  defp stop_users(0, _) do
    :ok
  end

  defp stop_users(_, []) do
    :ok
  end
end

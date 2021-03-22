defmodule Loadex.Stats do
  @moduledoc """
  Statistics module for Loadex.
  The stats data is fetched from workers periodically and stored in an ETS table.
  The actual number of sent requests with successful and error responses are printed out to console.
  """
  @stats_tab :loadex_stats

  @doc "Initialize stats ETS table."
  def init() do
    :ets.new(@stats_tab, [:named_table, :public])
  end

  @doc "Add a new worker to the configuration."
  def register_worker() do
    :ets.insert(@stats_tab, {self(), worker_stats()})
  end

  @doc """
  Update stats data with new entries.
  req_count: number of sent requests
  entry_count: number of successful requests
  error_count: number of failed requessts
  duration_since_last_update: milliseconds after latest stats update
  """
  def update_stats(%{
        req_count: req_count,
        entry_count: entry_count,
        error_count: error_count,
        duration_since_last_update: duration_ms
      }) do
    self_pid = self()

    stats =
      case :ets.lookup(@stats_tab, self_pid) do
        [{^self_pid, stats_rec}] -> stats_rec
        [] -> worker_stats()
      end

    %{request_count: total_requests, error_count: total_errors, entry_count: total_entries} =
      stats

    total_requests = total_requests + req_count
    total_entries = total_entries + entry_count
    total_errors = total_errors + error_count

    request_rate = calculate_rate(duration_ms, req_count)
    ingestion_rate = calculate_rate(duration_ms, entry_count)
    error_rate = calculate_rate(duration_ms, error_count)
    now_ms = now()

    # metrics notify: request_rate, ingestion_rate, error_rate

    stats = %{
      stats
      | request_count: total_requests,
        entry_count: total_entries,
        error_count: total_errors,
        entry_rate: ingestion_rate,
        request_rate: request_rate,
        error_rate: error_rate,
        last_update_ms: now_ms
    }

    :ets.insert(@stats_tab, {self_pid, stats})
  end

  @doc "Retrieve current stats data from ETS table."
  def get_stats() do
    all_stats = :ets.tab2list(@stats_tab)
    now_ms = now()

    sum_stats =
      Enum.reduce(
        all_stats,
        %{worker_stats() | last_update_ms: -1},
        fn {_k, %{last_update_ms: lu} = ws}, %{} = acc ->
          if diff(now_ms, lu) < 60000 do
            sum_stats(ws, acc)
          else
            acc
          end
        end
      )

    total_requests = sum_stats.request_count
    error_count = sum_stats.error_count

    error_pct =
      case total_requests do
        0 -> 0.0
        _ -> error_count * 100.0 / total_requests
      end

    Map.put(sum_stats, :error_pct, error_pct)
  end

  # TODO: update and get verification stats

  @doc "Current UTC time in internal format."
  def now() do
    Time.utc_now()
  end

  @doc "Difference between 2 internal timestamps in milliseconds."
  def diff(t1, t2) do
    Time.diff(t1, t2) * 1000
  end

  defp calculate_rate(duration_ms, count) do
    case duration_ms > 0 do
      true -> count * 1000 / duration_ms
      false -> 0.0
    end
  end

  defp sum_stats(
         %{
           request_count: arc,
           entry_count: aenc,
           error_count: aerc,
           request_rate: areqrate,
           entry_rate: aenrate,
           error_rate: aerrate
         },
         %{
           request_count: brc,
           entry_count: benc,
           error_count: berc,
           request_rate: breqrate,
           entry_rate: benrate,
           error_rate: berrate
         }
       ) do
    %{
      request_count: arc + brc,
      entry_count: aenc + benc,
      error_count: aerc + berc,
      request_rate: areqrate + breqrate,
      entry_rate: aenrate + benrate,
      error_rate: aerrate + berrate
    }
  end

  defp worker_stats() do
    %{
      last_update_ms: now(),
      request_count: 0,
      entry_count: 0,
      error_count: 0,
      request_rate: 0.0,
      entry_rate: 0.0,
      error_rate: 0.0
    }
  end
end

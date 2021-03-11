defmodule Loadex do
  @moduledoc """
  Documentation for `Loadex`.
  """

  @config_table :loadex_config

  def init_config_table() do
    :ets.new(@config_table, [:named_table, :public])
  end

  def add_config(config) do
    :ets.insert(@config_table, {config})
  end

  def start() do
    workers = Application.get_env(:loadex, :workers, 10)
    Loadex.Runner.start_link(%{workers: workers})
  end

  def stop() do
    Loadex.Runner.stop()
  end
end

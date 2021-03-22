defmodule Loadex do
  @moduledoc """
  Loadex load tester application API.
  """

  @config_table :loadex_config

  @doc "Initialize ETS table for storing configuration data: each user will issue a set of HTTP requests repeatedly."
  def init_config_table() do
    :ets.new(@config_table, [:named_table, :public])
  end

  @doc "Add configuration of one user to the ETS configuration table."
  def add_config(config) do
    :ets.insert(@config_table, {config})
  end

  @doc "Start a number of workers each representing a user. The user requests are fetched from the configuration table
  filled in via add_config/1."
  def start() do
    workers = Application.get_env(:loadex, :workers, 10)
    Loadex.Runner.start_link(%{workers: workers})
  end

  @doc "Stop test run including all workers."
  def stop() do
    Loadex.Runner.stop()
  end
end

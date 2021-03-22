defmodule Loadex.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    Loadex.init_config_table()

    children = []

    opts = [strategy: :one_for_one, name: Loadex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

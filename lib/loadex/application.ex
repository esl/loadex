defmodule Loadex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    workers = Application.get_env(:loadex, :workers, 10)
    requests = Application.get_env(:loadex, :requests, [%{method: :get, url: "http://www.google.com"}])
    children = [
      {Loadex.Runner, %{workers: workers, requests: requests}}
    ]

    opts = [strategy: :one_for_one, name: Loadex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

# loadex

## Description

Traffic generator tool for HTTP backends. Creates a pre-defined number of users (workers) who issue HTTP requests to the
backend in a repeated sequence.

### Configuration

Application configuration parameters:

```
config :loadex,
  workers: 10,                # number of user sessions
  max_sleep_time: 200,        # delay between 2 requests from 1 user (ms)
  stats_min_duration: 1000,   # frequency (ms) of updating statistics
  verification_percent: 3     # verification percentage (not used yet)
```

### Usage

The config table is initialized when the application starts. You can add a list of requests for each user via the following command. Note that each user config is unique and used only once. When a user config is used in a worker, it is removed from the config table. Make sure you have enough user configuration items in the table before starting the required number of workers.
```
Loadex.add_config(requests: [request1, request2, ...])
```
Where each request is according to the following format:
```
map(
  method :: :get | :post,
  headers :: [{name, value}],
  url :: String.t(),
  body :: String.t()}
  name :: String.t() # e.g. "authorization"
  value :: String.t() # e.g. "Bearer <bearer-token>"
)
```

When all users are configured, you can start the traffic generator via the command:
```
Loadex.start()
```

Loadex prints statistics periodically to the console until it is stopped:

```
Loadex.stop()
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `loadex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:loadex, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/loadex](https://hexdocs.pm/loadex).

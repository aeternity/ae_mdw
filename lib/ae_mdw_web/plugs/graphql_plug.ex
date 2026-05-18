defmodule AeMdwWeb.Plugs.GraphQLPlug do
  @moduledoc """
  Thin wrapper around Absinthe.Plug that reads query complexity settings
  at request time from application env (populated from runtime.exs).

  This allows `GRAPHQL_MAX_COMPLEXITY` to be changed per-instance without
  recompiling. Schema initialization (the expensive part) is still done once
  at compile time via the `@base_opts` module attribute.
  """

  @behaviour Plug

  # Schema init is done once at compile time; only complexity opts are injected
  # at request time below.
  @base_opts Absinthe.Plug.init(schema: AeMdwWeb.GraphQL.Schema)

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    opts =
      Map.merge(@base_opts, %{
        analyze_complexity: true,
        max_complexity: Application.get_env(:ae_mdw, :graphql_max_complexity, 1_000)
      })

    Absinthe.Plug.call(conn, opts)
  end
end

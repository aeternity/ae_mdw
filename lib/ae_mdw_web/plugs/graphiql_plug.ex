defmodule AeMdwWeb.Plugs.GraphiQLPlug do
  @moduledoc """
  Forwards to the Absinthe GraphiQL playground only when the
  GRAPHIQL_ENABLED environment variable is set to "true".

  Keeping the feature flag at request time (rather than compile time) lets
  operators enable or disable the UI on a running instance without a
  redeploy—useful when running multiple instances behind a load balancer and
  only wanting to expose the playground on internal/admin nodes.
  """

  @behaviour Plug

  @graphiql_opts Absinthe.Plug.GraphiQL.init(
                   schema: AeMdwWeb.GraphQL.Schema,
                   interface: :playground
                 )

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    if Application.get_env(:ae_mdw, :graphiql_enabled, false) do
      Absinthe.Plug.GraphiQL.call(conn, @graphiql_opts)
    else
      conn
      |> Plug.Conn.send_resp(404, "GraphiQL is not enabled on this instance")
      |> Plug.Conn.halt()
    end
  end
end

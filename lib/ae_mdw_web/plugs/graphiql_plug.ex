defmodule AeMdwWeb.Plugs.GraphiQLPlug do
  @moduledoc """
  Forwards to the Absinthe GraphiQL playground only when the
  GRAPHIQL_ENABLED environment variable is set to "true".

  The flag is read from the Application environment, which is populated once
  at node startup from `runtime.exs`. Changing the environment variable on
  a running node has no effect — restart the node to pick up the new value.
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

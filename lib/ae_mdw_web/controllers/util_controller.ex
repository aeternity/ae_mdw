defmodule AeMdwWeb.UtilController do
  @moduledoc """
  Endpoint for observing Mdw state.
  """
  use AeMdwWeb, :controller
  use PhoenixSwagger

  alias AeMdw.Db.Status

  @spec status(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def status(conn, _params),
    do: json(conn, Status.node_and_mdw_status())

  @spec no_route(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def no_route(conn, _params),
    do: conn |> AeMdwWeb.Util.send_error(404, "no such route")

  @spec swagger_definitions() :: map()
  def swagger_definitions do
    %{
      StatusResponse:
        swagger_schema do
          title("Status response")
          description("Response schema for status")

          properties do
            mdw_height(:integer, "The height of the mdw", required: true)
            mdw_async_tasks(:map, "Async tasks counters of the mdw", required: true)
            mdw_synced(:boolean, "The synced status", required: true)
            mdw_tx_index(:integer, "The last transaction index", required: true)
            mdw_version(:string, "The mdw version", required: true)
            node_height(:integer, "The height of the node", required: true)
            node_progress(:integer, "Node syncing progress - 100 means synced", required: true)
            node_syncing(:boolean, "True if node is syncing", required: true)
            node_version(:string, "The node version", required: true)
          end

          example(%{
            mdw_height: 311_557,
            mdw_synced: true,
            mdw_tx_index: 15_474_067,
            mdw_version: "0.1.0",
            node_height: 311_557,
            node_version: "5.5.4"
          })
        end
    }
  end

  swagger_path :status do
    get("/status")
    description("Get middleware status.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_status")
    tag("Middleware")
    response(200, "Returns the status of the MDW", Schema.ref(:StatusResponse))
  end
end

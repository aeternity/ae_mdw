defmodule AeMdwWeb.UtilController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  def swagger_definitions do
    %{
      StatusResponse:
        swagger_schema do
          title("Status response")
          description("Response schema for status")

          properties do
            mdw_height(:integer, "The height of the mdw", required: true)
            mdw_synced(:boolean, "The synced status", required: true)
            mdw_tx_index(:integer, "The last transaction index", required: true)
            mdw_version(:string, "The mdw version", required: true)
            node_height(:integer, "The height of the node", required: true)
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

  def status(conn, _params) do
    {:ok, top_kb} = :aec_chain.top_key_block()
    {_, _, node_vsn} = Application.started_applications() |> List.keyfind(:aecore, 0)
    node_height = :aec_blocks.height(top_kb)
    mdw_height = AeMdw.Db.Util.last_gen()

    status = %{
      node_version: to_string(node_vsn),
      node_height: node_height,
      mdw_version: AeMdw.MixProject.project()[:version],
      mdw_height: mdw_height,
      mdw_tx_index: AeMdw.Db.Util.last_txi(),
      mdw_synced: node_height == mdw_height
    }

    json(conn, status)
  end

  def no_route(conn, _params),
    do: conn |> AeMdwWeb.Util.send_error(404, "no such route")
end

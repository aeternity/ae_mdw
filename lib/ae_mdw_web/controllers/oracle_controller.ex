defmodule AeMdwWeb.OracleController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Validate
  alias AeMdw.Db.Model
  alias AeMdw.Db.Format
  alias AeMdw.Db.Oracle
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Oracles
  alias AeMdwWeb.SwaggerParameters
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  require Model

  plug(PaginatedPlug)

  ##########

  @spec oracle(Conn.t(), map()) :: Conn.t()
  def oracle(conn, %{"id" => id} = params),
    do:
      Util.handle_input(conn, fn ->
        oracle_reply(conn, Validate.id!(id, [:oracle_pubkey]), Util.expand?(params))
      end)

  @spec inactive_oracles(Conn.t(), map()) :: Conn.t()
  def inactive_oracles(%Conn{assigns: assigns} = conn, _params) do
    %{pagination: pagination, cursor: cursor, expand?: expand?} = assigns

    {prev_cursor, oracles, next_cursor} =
      Oracles.fetch_inactive_oracles(pagination, cursor, expand?)

    Util.paginate(conn, prev_cursor, oracles, next_cursor)
  end

  @spec active_oracles(Conn.t(), map()) :: Conn.t()
  def active_oracles(%Conn{assigns: assigns} = conn, _params) do
    %{pagination: pagination, cursor: cursor, expand?: expand?} = assigns

    {prev_cursor, oracles, next_cursor} =
      Oracles.fetch_active_oracles(pagination, cursor, expand?)

    Util.paginate(conn, prev_cursor, oracles, next_cursor)
  end

  @spec oracles(Conn.t(), map()) :: Conn.t()
  def oracles(%Conn{assigns: assigns} = conn, _params) do
    %{pagination: pagination, cursor: cursor, expand?: expand?, scope: scope} = assigns

    {prev_cursor, oracles, next_cursor} =
      Oracles.fetch_oracles(pagination, scope, cursor, expand?)

    Util.paginate(conn, prev_cursor, oracles, next_cursor)
  end

  ##########

  @spec oracle_reply(Conn.t(), binary(), boolean()) :: Conn.t()
  def oracle_reply(conn, pubkey, expand?) do
    case Oracle.locate(pubkey) do
      {m_oracle, source} -> json(conn, Format.to_map(m_oracle, source, expand?))
      nil -> raise ErrInput.NotFound, value: Enc.encode(:oracle_pubkey, pubkey)
    end
  end

  ##########
  @spec swagger_definitions() :: term()
  def swagger_definitions do
    %{
      Format:
        swagger_schema do
          title("Format")
          description("Schema for format")

          properties do
            query(:string, "The query format", required: true)
            response(:string, "The response format", required: true)
          end

          example(%{query: "string", response: "string"})
        end,
      OracleResponse:
        swagger_schema do
          title("Oracle")
          description("Schema for oracle")

          properties do
            active(:boolean, "The oracle active status", required: true)

            active_from(:integer, "The block height when the oracle became active", required: true)

            expire_height(:integer, "The block height when the oracle expires", required: true)
            extends(:array, "The tx indexes when the oracle has been extended", required: true)
            format(Schema.ref(:Format), "The oracle's query and response formats", required: true)
            oracle(:string, "The oracle id", required: true)
            query_fee(:integer, "The query fee", required: true)
            register(:integer, "The tx index when the oracle is registered", required: true)
          end

          example(%{
            active: false,
            active_from: 4_660,
            expire_height: 6_894,
            extends: [11_025],
            format: %{query: "string", response: "string"},
            oracle: "ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM",
            query_fee: 20_000,
            register: 11_023
          })
        end,
      OraclesResponse:
        swagger_schema do
          title("Oracles")
          description("Schema for oracles")

          properties do
            data(Schema.array(:OracleResponse), "The data for the oracles", required: true)
            next(:string, "The continuation link", required: true, nullable: true)
          end

          example(%{
            data: [
              %{
                active: false,
                active_from: 307_850,
                expire_height: 308_350,
                extends: [],
                format: %{query: "string", response: "string"},
                oracle: "ok_sezvMRsriPfWdphKmv293hEiyeyUYSoqkWqW7AcAuW9jdkCnT",
                query_fee: 20_000_000_000_000,
                register: 15_198_855
              }
            ],
            next: "oracles/inactive/gen/317126-0?limit=1&page=2"
          })
        end
    }
  end

  swagger_path :oracle do
    get("/oracle/{id}")
    description("Get oracle information for given oracle id")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_oracle")
    tag("Middleware")

    parameters do
      id(:path, :string, "The oracle id",
        required: true,
        example: "ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM"
      )

      expand(:query, :boolean, "Expand tx indexes", required: false)
    end

    response(
      200,
      "Returns oracle information for given oracle id. If the expand is set to true, the mdw will return the data with full transaction info, otherwise it will return only transaction indexes",
      Schema.ref(:OracleResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :inactive_oracles do
    get("/oracles/inactive")
    description("Get inactive/expired oracles")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_inactive_oracles")
    tag("Middleware")
    SwaggerParameters.direction_params()
    SwaggerParameters.limit_and_page_params()
    parameter(:expand, :query, :boolean, "Expand tx indexes", required: false)

    response(
      200,
      "Returns information for all inactive oracles. If the expand is set to true, the mdw will return the data with full transaction info, otherwise it will return only transaction indexes",
      Schema.ref(:OraclesResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :active_oracles do
    get("/oracles/active")
    description("Get active oracles")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_active_oracles")
    tag("Middleware")
    SwaggerParameters.direction_params()
    SwaggerParameters.limit_and_page_params()
    parameter(:expand, :query, :boolean, "Expand tx indexes", required: false)

    response(
      200,
      "Returns information for all active oracles. If the expand is set to true, the mdw will return the data with full transaction info, otherwise it will return only transaction indexes",
      Schema.ref(:OraclesResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end

  swagger_path :oracles do
    get("/oracles")
    description("Get all oracles")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_oracles")
    tag("Middleware")
    SwaggerParameters.direction_params()
    SwaggerParameters.limit_and_page_params()
    parameter(:expand, :query, :boolean, "Expand tx indexes", required: false)

    response(
      200,
      "Returns information for all oracles. If the expand is set to true, the mdw will return the data with full transaction info, otherwise it will return only transaction indexes",
      Schema.ref(:OraclesResponse)
    )

    response(400, "Bad request", Schema.ref(:ErrorResponse))
  end
end

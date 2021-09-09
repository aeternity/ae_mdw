defmodule AeMdwWeb.OracleController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Validate
  alias AeMdw.Db.Model
  alias AeMdw.Db.Format
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Oracles
  alias AeMdwWeb.Continuation, as: Cont
  alias AeMdwWeb.SwaggerParameters
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias Plug.Conn

  require Model

  import AeMdwWeb.Util
  import AeMdw.Db.Util

  plug(PaginatedPlug)

  ##########

  def stream_plug_hook(%Plug.Conn{params: params} = conn) do
    alias AeMdwWeb.DataStreamPlug, as: P

    rem = rem_path(conn.path_info)

    P.handle_assign(
      conn,
      (rem == [] && {:ok, {:gen, last_gen()..0}}) || P.parse_scope(rem, ["gen"]),
      P.parse_offset(params),
      {:ok, %{}}
    )
  end

  defp rem_path(["oracles", x | rem]) when x in ["inactive", "active"], do: rem
  defp rem_path(["oracles" | rem]), do: rem

  ##########

  def oracle(conn, %{"id" => id} = params),
    do:
      handle_input(conn, fn ->
        oracle_reply(conn, Validate.id!(id, [:oracle_pubkey]), expand?(params))
      end)

  def inactive_oracles(conn, _req),
    do: handle_input(conn, fn -> Cont.response(conn, &json/2) end)

  def active_oracles(conn, _req),
    do: handle_input(conn, fn -> Cont.response(conn, &json/2) end)

  def oracles(conn, _req),
    do: handle_input(conn, fn -> Cont.response(conn, &json/2) end)

  def active_oracles_v2(%Conn{assigns: assigns} = conn, _params) do
    %{direction: direction, limit: limit, cursor: cursor} = assigns

    {oracles, new_cursor} = Oracles.fetch_active_oracles(direction, cursor, limit)

    uri =
      if new_cursor do
        %URI{
          path: "/v2/oracles/active/#{direction}",
          query: URI.encode_query(%{"cursor" => new_cursor, "limit" => limit})
        }
        |> URI.to_string()
      end

    json(conn, %{"data" => oracles, "next" => uri})
  end

  def inactive_oracles_v2(%Conn{assigns: assigns} = conn, _params) do
    %{direction: direction, limit: limit, cursor: cursor} = assigns

    {oracles, new_cursor} = Oracles.fetch_inactive_oracles(direction, cursor, limit)

    uri =
      if new_cursor do
        %URI{
          path: "/v2/oracles/inactive/#{direction}",
          query: URI.encode_query(%{"cursor" => new_cursor, "limit" => limit})
        }
        |> URI.to_string()
      end

    json(conn, %{"data" => oracles, "next" => uri})
  end

  ##########

  # scope is used here only for identification of the continuation
  def db_stream(:inactive_oracles, params, _scope),
    do: do_inactive_oracles_stream(validate_params!(params), expand?(params))

  def db_stream(:active_oracles, params, _scope),
    do: do_active_oracles_stream(validate_params!(params), expand?(params))

  def db_stream(:oracles, params, _scope),
    do: do_oracles_stream(validate_params!(params), expand?(params))

  ##########

  def oracle_reply(conn, pubkey, expand?) do
    with {m_oracle, source} <- Oracle.locate(pubkey) do
      json(conn, Format.to_map(m_oracle, source, expand?))
    else
      nil ->
        raise ErrInput.NotFound, value: Enc.encode(:oracle_pubkey, pubkey)
    end
  end

  ##########

  def do_inactive_oracles_stream(dir, expand?),
    do: DBS.Oracle.inactive_oracles(dir, exp_to_formatted_oracle(Model.InactiveOracle, expand?))

  def do_active_oracles_stream(dir, expand?),
    do: DBS.Oracle.active_oracles(dir, exp_to_formatted_oracle(Model.ActiveOracle, expand?))

  def do_oracles_stream(:forward, expand?),
    do:
      Stream.concat(
        do_inactive_oracles_stream(:forward, expand?),
        do_active_oracles_stream(:forward, expand?)
      )

  def do_oracles_stream(:backward, expand?),
    do:
      Stream.concat(
        do_active_oracles_stream(:backward, expand?),
        do_inactive_oracles_stream(:backward, expand?)
      )

  ##########

  def validate_params!(params),
    do: do_validate_params!(Map.delete(params, "expand"))

  def do_validate_params!(%{"direction" => [dir]}) do
    dir in ["forward", "backward"] || raise ErrInput.Query, value: "direction=#{dir}"
    String.to_atom(dir)
  end

  def do_validate_params!(_params),
    do: :backward

  def exp_to_formatted_oracle(table, expand?) do
    fn {:expiration, {_, pubkey}, _} ->
      case Oracle.locate(pubkey) do
        {m_oracle, ^table} -> Format.to_map(m_oracle, table, expand?)
        _ -> nil
      end
    end
  end

  ##########
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
            active_from: 4660,
            expire_height: 6894,
            extends: [11025],
            format: %{query: "string", response: "string"},
            oracle: "ok_R7cQfVN15F5ek1wBSYaMRjW2XbMRKx7VDQQmbtwxspjZQvmPM",
            query_fee: 20000,
            register: 11023
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

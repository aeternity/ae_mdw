defmodule AeMdwWeb.BlockController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Validate
  alias AeMdw.Db.{Model, Format}
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.Continuation, as: Cont
  require Model

  import AeMdwWeb.Util
  import AeMdw.{Util, Db.Util}

  ##########

  def stream_plug_hook(%Plug.Conn{path_info: ["blocks" | rem], params: params} = conn) do
    alias AeMdwWeb.DataStreamPlug, as: P

    scope_info =
      case rem do
        [x | _] when x in ["forward", "backward"] -> rem
        _ -> ensure_prefix("gen", rem)
      end

    P.handle_assign(
      conn,
      P.parse_scope(scope_info, ["gen"]),
      P.parse_offset(params),
      {:ok, %{}}
    )
  end

  ##########

  def block(conn, %{"hash" => hash}),
    do: handle_input(conn, fn -> block_reply(conn, hash) end)

  def blocki(conn, %{"kbi" => kbi} = req),
    do:
      handle_input(conn, fn ->
        mbi = Map.get(req, "mbi", "-1")
        block_reply(conn, Validate.block_index!(kbi <> "/" <> mbi))
      end)

  def blocks(conn, _req),
    do: Cont.response(conn, &json/2)

  ##########

  def db_stream(:blocks, _params, {:gen, range}),
    do: Stream.map(range, &generation(&1, last_gen()))

  ##########

  def generation(height, last_gen),
    do: generation(block_jsons(height, last_gen))

  def generation([kb_json | mb_jsons]) do
    mb_jsons =
      for %{"hash" => mb_hash} = mb_json <- mb_jsons, reduce: %{} do
        mbs ->
          micro = :aec_db.get_block(Validate.id!(mb_hash))
          header = :aec_blocks.to_header(micro)

          txs_json =
            for tx <- :aec_blocks.txs(micro), reduce: %{} do
              txs ->
                %{"hash" => tx_hash} = tx_json = :aetx_sign.serialize_for_client(header, tx)
                Map.put(txs, tx_hash, tx_json)
            end

          mb_json = Map.put(mb_json, "transactions", txs_json)
          Map.put(mbs, mb_hash, mb_json)
      end

    Map.put(kb_json, "micro_blocks", mb_jsons)
  end

  def block_jsons(height, last_gen) when height < last_gen do
    collect_keys(Model.Block, [], {height, <<>>}, &prev/2, fn
      {^height, _} = k, acc ->
        {:cont, [Format.to_map(read_block!(k)) | acc]}

      _k, acc ->
        {:halt, acc}
    end)
  end

  def block_jsons(last_gen, last_gen) do
    {:ok, %{key_block: kb, micro_blocks: mbs}} = :aec_chain.get_current_generation()
    ^last_gen = :aec_blocks.height(kb)

    for block <- [kb | mbs] do
      header = :aec_blocks.to_header(block)
      :aec_headers.serialize_for_client(header, prev_block_type(header))
    end
  end

  ##########

  def block_reply(conn, enc_block_hash) when is_binary(enc_block_hash) do
    block_hash = Validate.id!(enc_block_hash)

    case :aec_chain.get_block(block_hash) do
      {:ok, _} ->
        # note: the `nil` here - for json formatting, we reuse AE node code
        json(conn, Format.to_map({:block, {nil, nil}, nil, block_hash}))

      :error ->
        raise ErrInput.NotFound, value: enc_block_hash
    end
  end

  def block_reply(conn, {_, mbi} = block_index) do
    case read_block(block_index) do
      [block] ->
        type = (mbi == -1 && :key_block_hash) || :micro_block_hash
        hash = Model.block(block, :hash)
        block_reply(conn, Enc.encode(type, hash))

      [] ->
        raise ErrInput.NotFound, value: block_index
    end
  end

  ########

  swagger_path :block do
    get("/block/{hash}")
    description("Get block information by given key/micro block hash.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_block_by_hash")
    tag("Middleware")

    parameters do
      hash(:path, :string, "The key/micro block hash.",
        required: true,
        example: "kh_uoTGwc4HPzEW9qmiQR1zmVVdHmzU6YmnVvdFe6HvybJJRj7V6"
      )
    end

    response(
      200,
      "Returns block information by given key/micro block hash.",
      %{}
    )

    response(400, "Bad request.", %{})
  end

  swagger_path :blocks do
    get("/blocks/{range_or_dir}")
    description("Get multiple generations.")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_blocks")
    tag("Middleware")

    parameters do
      range_or_dir(
        :path,
        :string,
        "The direction, which could be **forward** or **backward**, or non-negative integer range.",
        required: true,
        example: "300000-300100"
      )

      limit(
        :query,
        :integer,
        "The numbers of items to return.",
        required: false,
        format: "int32",
        default: 10,
        minimum: 1,
        maximum: 1000,
        example: 1
      )
    end

    response(200, "Returns multiple generations.", %{})
    response(400, "Bad request.", %{})
  end

  swagger_path :blocki_kbi do
    get("/blocki/{kbi}")
    description("Get key block information by given key block index(height).")
    produces(["application/json"])
    deprecated(false)
    operation_id("get_block_by_kbi")
    tag("Middleware")

    parameters do
      kbi(:path, :integer, "The key block index(height).",
        required: true,
        example: 305_000
      )
    end

    response(200, "Returns key block information by given key block index(height).", %{})
    response(400, "Bad request.", %{})
  end

  swagger_path :blocki_kbi_and_mbi do
    get("/blocki/{kbi}/{mbi}")

    description(
      "Get micro block information by given key block index(height) and micro block index."
    )

    produces(["application/json"])
    deprecated(false)
    operation_id("get_block_by_kbi_and_mbi")
    tag("Middleware")

    parameters do
      kbi(:path, :integer, "The key block index(height).",
        required: true,
        example: 300_001
      )

      mbi(:path, :integer, "The micro block index.",
        required: true,
        example: 4
      )
    end

    response(
      200,
      "Returns micro block information by given key block index(height) and micro block index.",
      %{}
    )

    response(400, "Bad request.", %{})
  end

  def swagger_path_blocki(route = %{path: "/blocki/{kbi}"}), do: swagger_path_blocki_kbi(route)

  def swagger_path_blocki(route = %{path: "/blocki/{kbi}/{mbi}"}),
    do: swagger_path_blocki_kbi_and_mbi(route)
end

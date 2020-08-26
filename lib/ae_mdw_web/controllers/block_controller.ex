defmodule AeMdwWeb.BlockController do
  use AeMdwWeb, :controller

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

    P.handle_assign(
      conn,
      (rem == [] &&
         {:ok, {:gen, last_gen()..0}}) ||
        P.parse_scope(ensure_prefix("gen", rem), ["gen"]),
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
end

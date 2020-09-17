defmodule AeMdw.Db.Format do
  alias AeMdw.Node, as: AE
  alias :aeser_api_encoder, as: Enc

  alias AeMdw.Db.{Model, Name}

  require Model

  import AeMdw.Db.Name, only: [plain_name!: 1]
  import AeMdw.{Util, Db.Util}

  ##########

  def bi_txi_txi({{_height, _mbi}, txi}), do: txi

  def to_raw_map({{height, mbi}, txi}),
    do: %{block_height: height, micro_index: mbi, tx_index: txi}

  def to_raw_map({:block, {_kbi, mbi}, _txi, hash}),
    do: record_to_map(:aec_db.get_header(hash), AE.hdr_fields((mbi == -1 && :key) || :micro))

  def to_raw_map({:tx, _index, hash, {_kb_index, _mb_index}, _mb_time} = mdw_tx),
    do: to_raw_map(mdw_tx, AE.Db.get_tx_data(hash))

  def to_raw_map(
        {:tx, index, hash, {kb_index, mb_index}, mb_time},
        {block_hash, type, signed_tx, tx_rec}
      ) do
    tx_map = to_raw_map(tx_rec, type) |> put_in([:type], type)

    raw = %{
      block_hash: block_hash,
      signatures: :aetx_sign.signatures(signed_tx),
      hash: hash,
      block_height: kb_index,
      micro_index: mb_index,
      micro_time: mb_time,
      tx_index: index,
      tx: tx_map
    }

    custom_raw_data(type, raw, tx_rec, signed_tx, block_hash)
  end

  def to_raw_map({:auction_bid, key, _}, Model.AuctionBid),
    do: to_raw_map(key, Model.AuctionBid)

  def to_raw_map({_plain, {{_, _}, _}, _, [{_, _} | _]} = bid, Model.AuctionBid),
    do: auction_bid(bid, & &1, &to_raw_map/1, & &1)

  def to_raw_map(m_name, source) when elem(m_name, 0) == :name do
    succ = &Model.name(&1, :previous)
    prev = chase(succ.(m_name), succ)

    %{
      name: Model.name(m_name, :index),
      status: :name,
      active: source == Model.ActiveName,
      info: name_info_to_raw_map(m_name),
      previous: Enum.map(prev, &name_info_to_raw_map/1)
    }
  end

  def to_raw_map(m_oracle, source) when elem(m_oracle, 0) == :oracle do
    alias AeMdw.Node, as: AE

    pk = Model.oracle(m_oracle, :index)
    {{register_height, _}, register_txi} = Model.oracle(m_oracle, :register)
    expire_height = Model.oracle(m_oracle, :expire)

    kbi = min(expire_height - 1, last_gen())
    oracle_tree = AeMdw.Db.Oracle.oracle_tree!({kbi, -1})
    oracle_rec = :aeo_state_tree.get_oracle(pk, oracle_tree)

    %{
      oracle: :aeser_id.create(:oracle, pk),
      active: source == Model.ActiveOracle,
      active_from: register_height,
      expire_height: expire_height,
      register: register_txi,
      extends: Enum.map(Model.oracle(m_oracle, :extends), &bi_txi_txi/1),
      query_fee: AE.Oracle.get!(oracle_rec, :query_fee),
      format: %{
        query: AE.Oracle.get!(oracle_rec, :query_format),
        response: AE.Oracle.get!(oracle_rec, :response_format)
      }
    }
  end

  def to_raw_map(ae_tx, tx_type) do
    AeMdw.Node.tx_fields(tx_type)
    |> Stream.with_index(1)
    |> Enum.reduce(
      %{},
      fn {field, pos}, acc ->
        put_in(acc[field], elem(ae_tx, pos))
      end
    )
  end

  def custom_raw_data(:contract_create_tx, tx, tx_rec, _signed_tx, _block_hash) do
    contract_pk = :aect_contracts.pubkey(:aect_contracts.new(tx_rec))
    put_in(tx, [:tx, :contract_id], :aeser_id.create(:contract, contract_pk))
  end

  def custom_raw_data(:contract_call_tx, tx, tx_rec, _signed_tx, block_hash) do
    alias AeMdw.Contract, as: C
    contract_pk = :aect_call_tx.contract_pubkey(tx_rec)
    {fun_arg_res, call_rec} = C.call_tx_info(tx_rec, contract_pk, block_hash, &C.to_map/1)

    logs = fn logs ->
      Enum.map(logs, fn {addr, topics, data} ->
        %{address: addr, topics: topics, data: data}
      end)
    end

    call_info = %{
      call_id: :aect_call.id(call_rec),
      return_type: :aect_call.return_type(call_rec),
      gas_used: :aect_call.gas_used(call_rec),
      log: logs.(:aect_call.log(call_rec))
    }

    update_in(tx, [:tx], &Map.merge(&1, Map.merge(call_info, fun_arg_res)))
  end

  def custom_raw_data(:channel_create_tx, tx, _tx_rec, signed_tx, _block_hash) do
    channel_pk = :aesc_utils.channel_pubkey(signed_tx) |> ok!
    put_in(tx, [:tx, :channel_id], :aeser_id.create(:channel, channel_pk))
  end

  def custom_raw_data(:oracle_register_tx, tx, tx_rec, _signed_tx, _block_hash) do
    oracle_pk = :aeo_register_tx.account_pubkey(tx_rec)
    put_in(tx, [:tx, :oracle_id], :aeser_id.create(:oracle, oracle_pk))
  end

  def custom_raw_data(:name_claim_tx, tx, tx_rec, _signed_tx, _block_hash) do
    {:ok, name_id} = :aens.get_name_hash(:aens_claim_tx.name(tx_rec))
    put_in(tx, [:tx, :name_id], :aeser_id.create(:name, name_id))
  end

  def custom_raw_data(:name_update_tx, tx, tx_rec, _signed_tx, _block_hash),
    do: put_in(tx, [:tx, :name], plain_name!(:aens_update_tx.name_hash(tx_rec)))

  def custom_raw_data(:name_transfer_tx, tx, tx_rec, _signed_tx, _block_hash),
    do: put_in(tx, [:tx, :name], plain_name!(:aens_transfer_tx.name_hash(tx_rec)))

  def custom_raw_data(:name_revoke_tx, tx, tx_rec, _signed_tx, _block_hash),
    do: put_in(tx, [:tx, :name], plain_name!(:aens_revoke_tx.name_hash(tx_rec)))

  def custom_raw_data(_, tx, _, _, _),
    do: tx

  ##########

  def to_map({{_height, _mbi}, _txi} = bi_txi),
    do: raw_to_json(to_raw_map(bi_txi))

  def to_map({:block, {_kbi, _mbi}, _txi, hash}) do
    header = :aec_db.get_header(hash)
    :aec_headers.serialize_for_client(header, prev_block_type(header))
  end

  def to_map({:tx, _index, hash, {_kb_index, _mb_index}, _mb_time} = rec),
    do: to_map(rec, AE.Db.get_tx_data(hash))

  def to_map(
        {:tx, index, _hash, {_kb_index, mb_index}, mb_time},
        {block_hash, type, signed_tx, tx_rec}
      ) do
    header = :aec_db.get_header(block_hash)
    enc_tx = :aetx_sign.serialize_for_client(header, signed_tx)

    custom_encode(type, enc_tx, tx_rec, signed_tx, block_hash)
    |> put_in(["tx_index"], index)
    |> put_in(["micro_index"], mb_index)
    |> put_in(["micro_time"], mb_time)
  end

  def to_map({:auction_bid, key, _}, Model.AuctionBid),
    do: to_map(key, Model.AuctionBid)

  def to_map({_plain, {{_, _}, _}, _, [{_, _} | _]} = bid, Model.AuctionBid),
    do: auction_bid(bid, &to_string/1, &to_map/1, &raw_to_json/1)

  def to_map(name, source) when source in [Model.ActiveName, Model.InactiveName],
    do: raw_to_json(to_raw_map(name, source))

  def to_map(oracle, source) when source in [Model.ActiveOracle, Model.InactiveOracle],
    do:
      map_raw_values(to_raw_map(oracle, source), fn
        {:id, :oracle, pk} -> Enc.encode(:oracle_pubkey, pk)
        x -> to_json(x)
      end)

  def to_map(data, source, false = _expand),
    do: to_map(data, source)

  def to_map(name, source, true = _expand)
      when source in [Model.ActiveName, Model.InactiveName] do
    to_map(name, source)
    |> update_in(["info"], &expand_name_info/1)
    |> update_in(["previous"], fn prevs -> Enum.map(prevs, &expand_name_info/1) end)
  end

  def to_map(bid, Model.AuctionBid, true = _expand) do
    to_map(bid, Model.AuctionBid)
    |> update_in(["info", "bids"], fn claims -> Enum.map(claims, &expand/1) end)
    |> update_in(["previous"], fn prevs -> Enum.map(prevs, &expand_name_info/1) end)
  end

  def custom_encode(:oracle_response_tx, tx, _tx_rec, _signed_tx, _block_hash),
    do: update_in(tx, ["tx", "response"], &maybe_base64/1)

  def custom_encode(:contract_create_tx, tx, tx_rec, _, _block_hash) do
    contract_pk = :aect_contracts.pubkey(:aect_contracts.new(tx_rec))
    put_in(tx, ["tx", "contract_id"], Enc.encode(:contract_pubkey, contract_pk))
  end

  def custom_encode(:contract_call_tx, tx, tx_rec, _signed_tx, block_hash) do
    alias AeMdw.Contract, as: C
    contract_pk = :aect_call_tx.contract_pubkey(tx_rec)
    {fun_arg_res, call_rec} = C.call_tx_info(tx_rec, contract_pk, block_hash, &C.to_json/1)
    fun_arg_res = Enum.into(Enum.map(fun_arg_res, fn {k, v} -> {to_string(k), v} end), %{})
    stringify = fn xs -> Enum.map(xs, &to_string/1) end
    log_entry = fn log -> Map.update(log, "topics", [], stringify) end

    call_ser =
      :aect_call.serialize_for_client(call_rec)
      |> Map.drop(["return_value", "gas_price", "height", "contract_id", "caller_nonce"])
      |> Map.update("log", [], fn logs -> Enum.map(logs, log_entry) end)

    update_in(tx, ["tx"], &Map.merge(&1, Map.merge(fun_arg_res, call_ser)))
  end

  def custom_encode(:channel_create_tx, tx, _tx_rec, signed_tx, _block_hash) do
    channel_pk = :aesc_utils.channel_pubkey(signed_tx) |> ok!
    put_in(tx, ["tx", "channel_id"], Enc.encode(:channel, channel_pk))
  end

  def custom_encode(:oracle_register_tx, tx, tx_rec, _signed_tx, _block_hash) do
    oracle_pk = :aeo_register_tx.account_pubkey(tx_rec)
    put_in(tx, ["tx", "oracle_id"], Enc.encode(:oracle_pubkey, oracle_pk))
  end

  def custom_encode(:name_claim_tx, tx, tx_rec, _signed_tx, _block_hash) do
    {:ok, name_id} = :aens.get_name_hash(:aens_claim_tx.name(tx_rec))
    put_in(tx, ["tx", "name_id"], Enc.encode(:name, name_id))
  end

  def custom_encode(:name_update_tx, tx, tx_rec, _signed_tx, _block_hash),
    do: put_in(tx, ["tx", "name"], plain_name!(:aens_update_tx.name_hash(tx_rec)))

  def custom_encode(:name_transfer_tx, tx, tx_rec, _signed_tx, _block_hash),
    do: put_in(tx, ["tx", "name"], plain_name!(:aens_transfer_tx.name_hash(tx_rec)))

  def custom_encode(:name_revoke_tx, tx, tx_rec, _signed_tx, _block_hash),
    do: put_in(tx, ["tx", "name"], plain_name!(:aens_revoke_tx.name_hash(tx_rec)))

  def custom_encode(_, tx, _, _, _),
    do: tx

  def maybe_base64(bin) do
    try do
      dec = :base64.decode(bin)
      (String.valid?(dec) && dec) || bin
    rescue
      _ -> bin
    end
  end

  def raw_to_json(x),
    do: map_raw_values(x, &to_json/1)

  def to_json({:id, idtype, payload}),
    do: Enc.encode(AE.id_type(idtype), payload)

  def to_json(x),
    do: x

  def map_raw_values(m, f) when is_map(m),
    do: m |> Enum.map(fn {k, v} -> {to_string(k), map_raw_values(v, f)} end) |> Enum.into(%{})

  def map_raw_values(l, f) when is_list(l),
    do: l |> Enum.map(&map_raw_values(&1, f))

  def map_raw_values(x, f),
    do: f.(x)

  defp name_info_to_raw_map(
         {:name, _, active_h, expire_h, cs, us, ts, revoke, auction_tm, _prev} = n
       ),
       do: %{
         active_from: active_h,
         expire_height: expire_h,
         claims: Enum.map(cs, &bi_txi_txi/1),
         updates: Enum.map(us, &bi_txi_txi/1),
         transfers: Enum.map(ts, &bi_txi_txi/1),
         revoke: (revoke && to_raw_map(revoke)) || nil,
         auction_timeout: auction_tm,
         pointers: Name.pointers(n),
         ownership: Name.ownership(n)
       }

  defp auction_bid({plain, {_, _}, auction_end, [{_, txi} | _] = bids}, key, tx_fmt, info_fmt),
    do: %{
      key.(:name) => plain,
      key.(:status) => :auction,
      key.(:active) => false,
      key.(:info) => %{
        key.(:auction_end) => auction_end,
        key.(:last_bid) => tx_fmt.(read_tx!(txi)),
        key.(:bids) => Enum.map(bids, &bi_txi_txi/1)
      },
      key.(:previous) =>
        case Name.locate(plain) do
          {m_name, Model.InactiveName} ->
            succ = &Model.name(&1, :previous)
            Enum.map(chase(m_name, succ), &info_fmt.(name_info_to_raw_map(&1)))

          _ ->
            []
        end
    }

  defp expand_name_info(json) do
    json
    |> update_in(["claims"], &expand/1)
    |> update_in(["updates"], &expand/1)
    |> update_in(["transfers"], &expand/1)
    |> update_in(["revoke"], &expand/1)
  end

  defp expand(txis) when is_list(txis),
    do: Enum.map(txis, &to_map(read_tx!(&1)))

  defp expand(txi) when is_integer(txi),
    do: to_map(read_tx!(txi))

  defp expand(nil),
    do: nil
end

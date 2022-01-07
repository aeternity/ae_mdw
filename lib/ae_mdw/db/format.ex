defmodule AeMdw.Db.Format do
  # credo:disable-for-this-file
  alias AeMdw.Node, as: AE
  alias :aeser_api_encoder, as: Enc

  alias AeMdw.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.Origin
  alias AeMdw.Txs

  require Model

  import AeMdw.Db.Name, only: [plain_name!: 1]
  import AeMdw.Util
  import AeMdw.Db.Util

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

  def to_raw_map({_plain, {{_, _}, _}, _, _, [{_, _} | _]} = bid, Model.AuctionBid),
    do: auction_bid(bid, & &1, &to_raw_map/1, & &1)

  def to_raw_map(m_name, source) when elem(m_name, 0) == :name do
    plain_name = Model.name(m_name, :index)
    succ = &Model.name(&1, :previous)
    prev = chase(succ.(m_name), succ)

    name_hash =
      case :aens.get_name_hash(plain_name) do
        {:ok, name_id_bin} -> Enc.encode(:name, name_id_bin)
        _error -> nil
      end

    {status, auction} =
      case Name.locate_bid(plain_name) do
        nil -> {:name, nil}
        key -> {:auction, to_raw_map(key, Model.AuctionBid)}
      end

    %{
      name: plain_name,
      hash: name_hash,
      auction: auction,
      status: status,
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

  def to_raw_map({name, symbol, txi, decimals}, Model.Aex9Contract) do
    %{
      name: name,
      symbol: symbol,
      decimals: decimals,
      contract_txi: txi,
      contract_id: :aeser_id.create(:contract, Origin.pubkey({:contract, txi}))
    }
  end

  def to_raw_map({symbol, name, txi, decimals}, Model.Aex9ContractSymbol),
    do: to_raw_map({name, symbol, txi, decimals}, Model.Aex9Contract)

  def to_raw_map({txi, name, symbol, decimals}, Model.RevAex9Contract),
    do: to_raw_map({name, symbol, txi, decimals}, Model.Aex9Contract)

  def to_raw_map({create_txi, call_txi, event_hash, log_idx}, Model.ContractLog) do
    m_log = read!(Model.ContractLog, {create_txi, call_txi, event_hash, log_idx})
    ct_id = &:aeser_id.create(:contract, &1)

    ct_pk =
      if create_txi == -1 do
        Origin.pubkey({:contract_call, call_txi})
      else
        Origin.pubkey({:contract, create_txi})
      end

    ext_ct_pk = Model.contract_log(m_log, :ext_contract)

    parent_contract_pk =
      case ext_ct_pk do
        {:parent_contract_pk, pct_pk} -> pct_pk
        _ -> nil
      end

    # clear ext_ct_pk after saving parent_contract_pk in its own field
    ext_ct_pk = if not is_tuple(ext_ct_pk), do: ext_ct_pk
    ext_ct_txi = (ext_ct_pk && Origin.tx_index({:contract, ext_ct_pk})) || -1
    m_tx = read!(Model.Tx, call_txi)

    {height, micro_index} = Model.tx(m_tx, :block_index)
    block_hash = Model.block(read_block!({height, micro_index}), :hash)

    %{
      contract_txi: (create_txi != -1 && create_txi) || -1,
      contract_id: ct_id.(ct_pk),
      ext_caller_contract_txi: ext_ct_txi,
      ext_caller_contract_id: (ext_ct_pk != nil && ct_id.(ext_ct_pk)) || nil,
      parent_contract_id: (parent_contract_pk && ct_id.(parent_contract_pk)) || nil,
      call_txi: call_txi,
      call_tx_hash: Model.tx(m_tx, :id),
      args: Model.contract_log(m_log, :args),
      data: Model.contract_log(m_log, :data),
      event_hash: event_hash,
      height: height,
      micro_index: micro_index,
      block_hash: block_hash,
      log_idx: log_idx
    }
  end

  def to_raw_map({call_txi, local_idx}, Model.IntContractCall) do
    m_call = read!(Model.IntContractCall, {call_txi, local_idx})
    create_txi = Model.int_contract_call(m_call, :create_txi)
    fname = Model.int_contract_call(m_call, :fname)

    ct_pk =
      case Origin.pubkey({:contract, create_txi}) do
        nil -> nil
        pk -> :aeser_id.create(:contract, pk)
      end

    m_tx = read!(Model.Tx, call_txi)
    {height, micro_index} = Model.tx(m_tx, :block_index)
    block_hash = Model.block(read_block!({height, micro_index}), :hash)

    %{
      contract_txi: (create_txi != -1 && create_txi) || nil,
      contract_id: ct_pk,
      call_txi: call_txi,
      call_tx_hash: Model.tx(m_tx, :id),
      function: fname,
      internal_tx: Model.int_contract_call(m_call, :tx),
      height: height,
      micro_index: micro_index,
      block_hash: block_hash,
      local_idx: local_idx
    }
  end

  def to_raw_map({{height, _txi}, kind, target_pk, ref_txi} = key, Model.IntTransferTx) do
    m_transfer = read!(Model.IntTransferTx, key)
    amount = Model.int_transfer_tx(m_transfer, :amount)

    %{
      height: height,
      account_id: target_pk,
      amount: amount,
      kind: kind,
      ref_txi: (ref_txi >= 0 && ref_txi) || nil
    }
  end

  def to_raw_map(m_stat, Model.Stat) do
    %{
      height: Model.stat(m_stat, :index),
      inactive_names: Model.stat(m_stat, :inactive_names),
      active_names: Model.stat(m_stat, :active_names),
      active_auctions: Model.stat(m_stat, :active_auctions),
      inactive_oracles: Model.stat(m_stat, :inactive_oracles),
      active_oracles: Model.stat(m_stat, :active_oracles),
      contracts: Model.stat(m_stat, :contracts),
      block_reward: Model.stat(m_stat, :block_reward),
      dev_reward: Model.stat(m_stat, :dev_reward)
    }
  end

  def to_raw_map(m_stat, Model.SumStat) do
    %{
      height: Model.stat(m_stat, :index),
      sum_block_reward: Model.sum_stat(m_stat, :block_reward),
      sum_dev_reward: Model.sum_stat(m_stat, :dev_reward),
      total_token_supply: Model.sum_stat(m_stat, :total_supply)
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

  def custom_raw_data(:contract_create_tx, tx, tx_rec, _signed_tx, block_hash) do
    contract_pk = :aect_contracts.pubkey(:aect_contracts.new(tx_rec))
    init_call_details = Contract.get_init_call_details(contract_pk, tx_rec, block_hash)

    update_in(tx, [:tx], fn tx_details -> Map.merge(tx_details, init_call_details) end)
  end

  def custom_raw_data(:contract_call_tx, tx, tx_rec, _signed_tx, block_hash) do
    contract_pk = :aect_call_tx.contract_pubkey(tx_rec)
    call_rec = Contract.call_rec(tx_rec, contract_pk, block_hash)
    fun_arg_res = AeMdw.Db.Contract.call_fun_arg_res(contract_pk, tx.tx_index)

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

    m = Map.merge(call_info, fun_arg_res)
    update_in(tx, [:tx], &Map.merge(&1, m))
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

    enc_tx =
      :aetx_sign.serialize_for_client(header, signed_tx)
      |> put_in(["tx_index"], index)
      |> put_in(["micro_index"], mb_index)
      |> put_in(["micro_time"], mb_time)

    custom_encode(type, enc_tx, tx_rec, signed_tx, block_hash)
  end

  def to_map({:auction_bid, key, _}, Model.AuctionBid),
    do: to_map(key, Model.AuctionBid)

  def to_map({_plain, {{_, _}, _}, _, _, [{_, _} | _]} = bid, Model.AuctionBid),
    do: auction_bid(bid, &to_string/1, &to_map/1, &raw_to_json/1)

  def to_map(m_name, source) when source in [Model.ActiveName, Model.InactiveName] do
    {raw_auction, raw_map} = Map.pop(to_raw_map(m_name, source), :auction)

    auction =
      map_some(
        raw_auction,
        fn %{info: info} ->
          info
          |> raw_to_json
          |> update_in(["last_bid"], fn bid ->
            bid
            |> update_in(["block_hash"], &Enc.encode(:micro_block_hash, &1))
            |> update_in(["hash"], &Enc.encode(:tx_hash, &1))
            |> update_in(["signatures"], fn ss -> Enum.map(ss, &Enc.encode(:signature, &1)) end)
            |> update_in(["tx", "type"], &AE.tx_name/1)
          end)
        end
      )

    raw_to_json(raw_map)
    |> put_in(["auction"], auction)
    |> update_in(["status"], &to_string/1)
  end

  def to_map(m_oracle, source) when source in [Model.ActiveOracle, Model.InactiveOracle],
    do:
      map_raw_values(to_raw_map(m_oracle, source), fn
        {:id, :oracle, pk} -> Enc.encode(:oracle_pubkey, pk)
        x -> to_json(x)
      end)

  def to_map({create_txi, call_txi, event_hash, log_idx}, Model.ContractLog),
    do:
      to_raw_map({create_txi, call_txi, event_hash, log_idx}, Model.ContractLog)
      |> update_in([:contract_id], &enc_id/1)
      |> update_in([:ext_caller_contract_id], &enc_id/1)
      |> update_in([:parent_contract_id], &enc_id/1)
      |> update_in([:call_tx_hash], &Enc.encode(:tx_hash, &1))
      |> update_in([:block_hash], &Enc.encode(:micro_block_hash, &1))
      |> update_in([:event_hash], &Base.hex_encode32/1)
      |> update_in([:args], fn args ->
        Enum.map(args, fn <<topic::256>> -> to_string(topic) end)
      end)

  def to_map({call_txi, local_idx}, Model.IntContractCall) do
    raw_map = to_raw_map({call_txi, local_idx}, Model.IntContractCall)

    int_tx = fn tx ->
      {tx_type, tx_rec} = :aetx.specialize_type(tx)
      serialized_tx = :aetx.serialize_for_client(tx)

      case tx_type do
        :contact_call_tx ->
          serialized_tx

        _ ->
          wrapped_tx = %{"tx" => serialized_tx}
          signed_tx = :aetx_sign.new(tx, [])

          %{"tx" => enc_tx} =
            custom_encode(tx_type, wrapped_tx, tx_rec, signed_tx, raw_map.block_hash)

          enc_tx
      end
    end

    raw_map
    |> update_in([:contract_id], &enc_id/1)
    |> update_in([:call_tx_hash], &Enc.encode(:tx_hash, &1))
    |> update_in([:block_hash], &Enc.encode(:micro_block_hash, &1))
    # &:aetx.serialize_for_client/1)
    |> update_in([:internal_tx], int_tx)
  end

  def to_map({{_height, _txi}, _kind, _target_pk, _ref_txi} = key, Model.IntTransferTx) do
    raw_map = to_raw_map(key, Model.IntTransferTx)

    raw_map
    |> update_in([:account_id], &Enc.encode(:account_pubkey, &1))
  end

  def to_map(m_stat, Model.Stat),
    do: to_raw_map(m_stat, Model.Stat)

  def to_map(m_stat, Model.SumStat),
    do: to_raw_map(m_stat, Model.SumStat)

  def to_map({_, _, _, _} = aex9_data, source)
      when source in [Model.Aex9Contract, Model.Aex9ContractSymbol, Model.RevAex9Contract],
      do: raw_to_json(to_raw_map(aex9_data, source))

  def to_map(data, source, false = _expand),
    do: to_map(data, source)

  def to_map(name, source, true = _expand)
      when source in [Model.ActiveName, Model.InactiveName] do
    to_map(name, source)
    |> update_in(["auction"], &expand_name_auction/1)
    |> update_in(["info"], &expand_name_info/1)
    |> update_in(["previous"], fn prevs -> Enum.map(prevs, &expand_name_info/1) end)
  end

  def to_map(bid, Model.AuctionBid, true = _expand) do
    to_map(bid, Model.AuctionBid)
    |> update_in(["info", "bids"], fn claims -> Enum.map(claims, &expand/1) end)
    |> update_in(["previous"], fn prevs -> Enum.map(prevs, &expand_name_info/1) end)
  end

  def to_map(oracle, source, true = _expand)
      when source in [Model.ActiveOracle, Model.InactiveOracle] do
    to_map(oracle, source)
    |> update_in(["extends"], fn exts -> Enum.map(exts, &expand/1) end)
    |> update_in(["register"], &expand/1)
  end

  def custom_encode(:oracle_response_tx, tx, _tx_rec, _signed_tx, _block_hash),
    do: update_in(tx, ["tx", "response"], &maybe_base64/1)

  def custom_encode(:oracle_query_tx, tx, tx_rec, _signed_tx, _block_hash) do
    query_id = :aeo_query_tx.query_id(tx_rec)
    query_id = Enc.encode(:oracle_query_id, query_id)

    tx
    |> update_in(["tx", "query"], &Base.encode64/1)
    |> put_in(["tx", "query_id"], query_id)
  end

  def custom_encode(:ga_attach_tx, tx, tx_rec, _signed_tx, _block_hash) do
    contract_pk = :aega_attach_tx.contract_pubkey(tx_rec)
    put_in(tx, ["tx", "contract_id"], Enc.encode(:contract_pubkey, contract_pk))
  end

  def custom_encode(:contract_create_tx, tx, tx_rec, _, block_hash) do
    contract_pk = :aect_contracts.pubkey(:aect_contracts.new(tx_rec))
    init_call_details = Contract.get_init_call_details(contract_pk, tx_rec, block_hash)

    update_in(tx, ["tx"], fn tx_details -> Map.merge(tx_details, init_call_details) end)
  end

  def custom_encode(:contract_call_tx, tx, tx_rec, _signed_tx, block_hash) do
    contract_pk = :aect_call_tx.contract_pubkey(tx_rec)
    call_rec = Contract.call_rec(tx_rec, contract_pk, block_hash)

    fun_arg_res =
      contract_pk
      |> AeMdw.Db.Contract.call_fun_arg_res(tx["tx_index"])
      |> map_raw_values(fn
        x when is_number(x) -> x
        x -> to_string(x)
      end)

    call_ser =
      :aect_call.serialize_for_client(call_rec)
      |> Map.drop(["return_value", "gas_price", "height", "contract_id", "caller_nonce"])
      |> Map.update("log", [], &Contract.stringfy_log_topics/1)

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
      _ -> :erlang.binary_to_list(bin)
    end
  end

  #
  # Private functions
  #
  defp enc_id(nil), do: nil

  defp enc_id({:id, idtype, payload}),
    do: Enc.encode(AE.id_type(idtype), payload)

  def raw_to_json(x),
    do: map_raw_values(x, &to_json/1)

  def to_json({:id, idtype, payload}),
    do: enc_id({:id, idtype, payload})

  def to_json(x),
    do: x

  def map_raw_values(m, f) when is_map(m),
    do: m |> Enum.map(fn {k, v} -> {to_string(k), map_raw_values(v, f)} end) |> Enum.into(%{})

  def map_raw_values(l, f) when is_list(l),
    do: l |> Enum.map(&map_raw_values(&1, f))

  def map_raw_values(x, f),
    do: f.(x)

  defp name_info_to_raw_map(
         {:name, _, active_h, expire_h, cs, us, ts, revoke, auction_tm, _owner, _prev} = n
       ),
       do: %{
         active_from: active_h,
         expire_height: expire_h,
         claims: Enum.map(cs, &bi_txi_txi/1),
         updates: Enum.map(us, &bi_txi_txi/1),
         transfers: Enum.map(ts, &bi_txi_txi/1),
         revoke: (revoke && bi_txi_txi(revoke)) || nil,
         auction_timeout: auction_tm,
         pointers: Name.pointers(n),
         ownership: Name.ownership(n)
       }

  defp auction_bid({plain, {_, _}, auction_end, _, [{_, txi} | _] = bids}, key, tx_fmt, info_fmt) do
    last_bid = tx_fmt.(read_tx!(txi))
    name_ttl = Name.expire_after(auction_end)
    keys = if Map.has_key?(last_bid, "tx"), do: ["tx", "ttl"], else: [:tx, :ttl]
    last_bid = put_in(last_bid, keys, name_ttl)

    %{
      key.(:name) => plain,
      key.(:status) => :auction,
      key.(:active) => false,
      key.(:info) => %{
        key.(:auction_end) => auction_end,
        key.(:last_bid) => last_bid,
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
  end

  defp expand_name_auction(nil), do: nil

  defp expand_name_auction(%{"bids" => bids_txis} = auction) do
    Map.put(auction, "bids", Enum.map(bids_txis, &Txs.fetch!/1))
  end

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

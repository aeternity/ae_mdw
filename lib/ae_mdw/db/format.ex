defmodule AeMdw.Db.Format do
  # credo:disable-for-this-file
  alias AeMdw.Node, as: AE
  alias :aeser_api_encoder, as: Enc

  alias AeMdw.Contract
  alias AeMdw.Channels
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Names
  alias AeMdw.Txs

  require Model

  import AeMdw.Util

  @type aeser_id() :: {:id, atom(), binary()}

  ##########

  def bi_txi_txi({{_height, _mbi}, txi}), do: txi

  def to_raw_map(_state, {{height, mbi}, txi}),
    do: %{block_height: height, micro_index: mbi, tx_index: txi}

  def to_raw_map(state, {:tx, _index, hash, {_kb_index, _mb_index}, _mb_time} = mdw_tx),
    do: to_raw_map(state, mdw_tx, AE.Db.get_tx_data(hash))

  def to_raw_map(
        state,
        {:tx, index, hash, {kb_index, mb_index}, mb_time},
        {block_hash, tx_type, signed_tx, tx_rec}
      ) do
    tx_map =
      tx_type
      |> AeMdw.Node.tx_fields()
      |> Enum.with_index(1)
      |> Enum.into(%{}, fn {field, pos} ->
        {field, elem(tx_rec, pos)}
      end)
      |> Map.put(:type, tx_type)

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

    custom_raw_data(state, tx_type, raw, tx_rec, signed_tx, block_hash)
  end

  def to_raw_map(state, auction_bid, Model.AuctionBid),
    do: auction_bid(state, auction_bid, & &1, &to_raw_map(state, &1), & &1)

  def to_raw_map(state, m_name, source) when elem(m_name, 0) == :name do
    plain_name = Model.name(m_name, :index)
    succ = &Model.name(&1, :previous)
    prev = chase(succ.(m_name), succ)

    name_hash =
      case :aens.get_name_hash(plain_name) do
        {:ok, name_id_bin} -> Enc.encode(:name, name_id_bin)
        _error -> nil
      end

    {status, auction} =
      case Name.locate_bid(state, plain_name) do
        nil ->
          {:name, nil}

        m_auction_bid ->
          {:auction, to_raw_map(state, m_auction_bid, Model.AuctionBid)}
      end

    %{
      name: plain_name,
      hash: name_hash,
      auction: auction,
      status: status,
      active: source == Model.ActiveName,
      info: name_info_to_raw_map(state, m_name),
      previous: Enum.map(prev, &name_info_to_raw_map(state, &1))
    }
  end

  @spec encode_pointers(list() | map()) :: %{iodata() => String.t()}
  def encode_pointers(pointers) when is_map(pointers) do
    Enum.into(pointers, %{}, fn {key, id} -> {maybe_to_list(key), enc_id(id)} end)
  end

  def encode_pointers(pointers) do
    Enum.map(pointers, fn
      %{"key" => key, "id" => id} -> %{"key" => maybe_to_list(key), "id" => id}
      %{key: key, id: id} -> %{key: maybe_to_list(key), id: id}
    end)
  end

  @spec enc_id(aeser_id() | nil) :: binary() | nil
  def enc_id(nil), do: nil

  def enc_id({:id, idtype, payload}),
    do: Enc.encode(AE.id_type(idtype), payload)

  defp custom_raw_data(_state, :contract_create_tx, tx, tx_rec, _signed_tx, block_hash) do
    init_call_details = Contract.get_init_call_details(tx_rec, block_hash)

    update_in(tx, [:tx], fn tx_details -> Map.merge(tx_details, init_call_details) end)
  end

  defp custom_raw_data(state, :contract_call_tx, tx, tx_rec, signed_tx, block_hash) do
    contract_pk = :aect_call_tx.contract_pubkey(tx_rec)
    call_rec = Contract.call_rec(signed_tx, contract_pk, block_hash)
    fun_arg_res = AeMdw.Db.Contract.call_fun_arg_res(state, contract_pk, tx.tx_index)

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

  defp custom_raw_data(_state, :channel_create_tx, tx, _tx_rec, signed_tx, _block_hash) do
    channel_pk = :aesc_utils.channel_pubkey(signed_tx) |> ok!
    put_in(tx, [:tx, :channel_id], :aeser_id.create(:channel, channel_pk))
  end

  defp custom_raw_data(_state, :oracle_register_tx, tx, tx_rec, _signed_tx, _block_hash) do
    oracle_pk = :aeo_register_tx.account_pubkey(tx_rec)
    put_in(tx, [:tx, :oracle_id], :aeser_id.create(:oracle, oracle_pk))
  end

  defp custom_raw_data(_state, :name_claim_tx, tx, tx_rec, _signed_tx, _block_hash) do
    {:ok, name_id} = :aens.get_name_hash(:aens_claim_tx.name(tx_rec))
    put_in(tx, [:tx, :name_id], :aeser_id.create(:name, name_id))
  end

  defp custom_raw_data(state, :name_update_tx, tx, tx_rec, _signed_tx, _block_hash) do
    tx
    |> put_in([:tx, :name], Name.plain_name!(state, :aens_update_tx.name_hash(tx_rec)))
    |> update_in([:tx, :pointers], &encode_pointers/1)
  end

  defp custom_raw_data(state, :name_transfer_tx, tx, tx_rec, _signed_tx, _block_hash),
    do: put_in(tx, [:tx, :name], Name.plain_name!(state, :aens_transfer_tx.name_hash(tx_rec)))

  defp custom_raw_data(state, :name_revoke_tx, tx, tx_rec, _signed_tx, _block_hash),
    do: put_in(tx, [:tx, :name], Name.plain_name!(state, :aens_revoke_tx.name_hash(tx_rec)))

  defp custom_raw_data(_state, _tx_type, tx, _tx_rec, _signed_tx, _block_hash),
    do: tx

  ##########

  def to_map(state, {:tx, _index, hash, {_kb_index, _mb_index}, _mb_time} = rec),
    do: to_map(state, rec, AE.Db.get_tx_data(hash))

  def to_map(
        state,
        {:tx, index, _hash, {_kb_index, mb_index}, mb_time},
        {block_hash, type, signed_tx, tx_rec}
      ) do
    header = :aec_db.get_header(block_hash)

    :aetx_sign.serialize_for_client(header, signed_tx)
    |> put_in(["tx_index"], index)
    |> put_in(["micro_index"], mb_index)
    |> put_in(["micro_time"], mb_time)
    |> update_in(["tx"], fn tx ->
      custom_encode(state, type, tx, tx_rec, signed_tx, index, block_hash)
    end)
  end

  def to_map(state, auction_bid, Model.AuctionBid),
    do: auction_bid(state, auction_bid, &to_string/1, &to_map(state, &1), &raw_to_json/1)

  def to_map(state, m_name, source) when source in [Model.ActiveName, Model.InactiveName] do
    {raw_auction, raw_map} = Map.pop(to_raw_map(state, m_name, source), :auction)

    auction =
      map_some(
        raw_auction,
        fn %{info: info} ->
          info
          |> raw_to_json()
          |> update_in(["last_bid"], fn bid ->
            bid
            |> update_in(["block_hash"], &Enc.encode(:micro_block_hash, &1))
            |> update_in(["hash"], &Enc.encode(:tx_hash, &1))
            |> update_in(["signatures"], fn ss -> Enum.map(ss, &Enc.encode(:signature, &1)) end)
            |> update_in(["tx", "type"], &AE.tx_name/1)
          end)
        end
      )

    raw_map
    |> raw_to_json()
    |> put_in(["auction"], auction)
  end

  def to_map(state, {call_txi, local_idx}, Model.IntContractCall) do
    m_call = State.fetch!(state, Model.IntContractCall, {call_txi, local_idx})
    create_txi = Model.int_contract_call(m_call, :create_txi)
    fname = Model.int_contract_call(m_call, :fname)

    ct_pk =
      case Origin.pubkey(state, {:contract, create_txi}) do
        nil -> nil
        pk -> :aeser_id.create(:contract, pk)
      end

    Model.tx(id: call_tx_hash, block_index: {height, micro_index}) =
      State.fetch!(state, Model.Tx, call_txi)

    Model.block(hash: block_hash) = DbUtil.read_block!(state, {height, micro_index})

    {contract_txi, contract_tx_hash} =
      if create_txi == -1 do
        {nil, nil}
      else
        {create_txi, Enc.encode(:tx_hash, Txs.txi_to_hash(state, create_txi))}
      end

    tx = Model.int_contract_call(m_call, :tx)
    {tx_type, tx_rec} = :aetx.specialize_type(tx)
    serialized_tx = :aetx.serialize_for_client(tx)

    encoded_tx =
      case tx_type do
        :contact_call_tx ->
          serialized_tx

        _tx_type ->
          signed_tx = :aetx_sign.new(tx, [])
          custom_encode(state, tx_type, serialized_tx, tx_rec, signed_tx, call_txi, block_hash)
      end

    %{
      contract_txi: contract_txi,
      contract_tx_hash: contract_tx_hash,
      contract_id: enc_id(ct_pk),
      call_txi: call_txi,
      call_tx_hash: Enc.encode(:tx_hash, call_tx_hash),
      function: fname,
      internal_tx: encoded_tx,
      height: height,
      micro_index: micro_index,
      block_hash: Enc.encode(:micro_block_hash, block_hash),
      local_idx: local_idx
    }
  end

  def to_map(state, data, source, false = _expand),
    do: to_map(state, data, source)

  def to_map(state, name, source, true = _expand)
      when source in [Model.ActiveName, Model.InactiveName] do
    to_map(state, name, source)
    |> update_in(["auction"], &expand_name_auction(state, &1))
    |> update_in(["info"], &expand_name_info(state, &1))
    |> update_in(["previous"], fn prevs -> Enum.map(prevs, &expand_name_info(state, &1)) end)
  end

  def to_map(state, bid, Model.AuctionBid, true = _expand) do
    to_map(state, bid, Model.AuctionBid)
    |> update_in(["info", "bids"], fn claims -> Enum.map(claims, &expand(state, &1)) end)
    |> update_in(["previous"], fn prevs -> Enum.map(prevs, &expand_name_info(state, &1)) end)
  end

  defp custom_encode(state, :channel_settle_tx, tx, tx_rec, _signed_tx, _txi, _block_hash) do
    pubkey = tx_rec |> :aesc_settle_tx.channel_id() |> :aeser_id.specialize(:channel)
    {:ok, Model.channel(responder: responder)} = Channels.fetch_channel(state, pubkey)
    responder_id = :aeser_id.create(:account, responder)
    Map.put(tx, "responder_id", enc_id(responder_id))
  end

  defp custom_encode(_state, :oracle_register_tx, tx, tx_rec, _signed_tx, _txi, _block_hash) do
    oracle_pk = :aeo_register_tx.account_pubkey(tx_rec)

    tx
    |> Map.put("oracle_id", Enc.encode(:oracle_pubkey, oracle_pk))
    |> Map.update("query_format", nil, &maybe_to_list/1)
    |> Map.update("response_format", nil, &maybe_to_list/1)
  end

  defp custom_encode(_state, :oracle_response_tx, tx, _tx_rec, _signed_tx, _txi, _block_hash),
    do: update_in(tx, ["response"], &maybe_base64/1)

  defp custom_encode(_state, :oracle_query_tx, tx, tx_rec, _signed_tx, _txi, _block_hash) do
    query_id = :aeo_query_tx.query_id(tx_rec)
    query_id = Enc.encode(:oracle_query_id, query_id)

    tx
    |> update_in(["query"], &Base.encode64/1)
    |> put_in(["query_id"], query_id)
  end

  defp custom_encode(_state, :ga_attach_tx, tx, tx_rec, signed_tx, _txi, block_hash) do
    contract_pk = :aega_attach_tx.contract_pubkey(tx_rec)
    call_details = Contract.get_ga_attach_call_details(signed_tx, contract_pk, block_hash)

    tx
    |> Map.put("contract_id", Enc.encode(:contract_pubkey, contract_pk))
    |> Map.merge(call_details)
  end

  defp custom_encode(_state, :ga_meta_tx, tx, tx_rec, _signed_tx, _txi, block_hash) do
    owner_pk = :aega_meta_tx.origin(tx_rec)
    auth_id = :aega_meta_tx.auth_id(tx_rec)

    case :aec_chain.get_ga_call(owner_pk, auth_id, block_hash) do
      {:ok, ga_object} ->
        tx
        |> Map.put("return_type", :aega_call.return_type(ga_object))
        |> Map.put("gas_used", :aega_call.gas_used(ga_object))

      _error_revert ->
        tx
        |> Map.put("return_type", :unknown)
        |> Map.put("gas_used", nil)
    end
  end

  defp custom_encode(_state, :contract_create_tx, tx, tx_rec, _signed_tx, _txi, block_hash) do
    init_call_details = Contract.get_init_call_details(tx_rec, block_hash)

    Map.merge(tx, init_call_details)
  end

  defp custom_encode(state, :contract_call_tx, tx, tx_rec, signed_tx, txi, block_hash) do
    contract_pk = :aect_call_tx.contract_pubkey(tx_rec)
    call_rec = Contract.call_rec(signed_tx, contract_pk, block_hash)

    fun_arg_res =
      state
      |> AeMdw.Db.Contract.call_fun_arg_res(contract_pk, txi)
      |> map_raw_values(fn
        x when is_number(x) -> x
        x -> to_string(x)
      end)

    call_ser =
      :aect_call.serialize_for_client(call_rec)
      |> Map.drop(["return_value", "gas_price", "height", "contract_id", "caller_nonce"])
      |> Map.update("log", [], &Contract.stringfy_log_topics/1)

    Map.merge(tx, Map.merge(fun_arg_res, call_ser))
  end

  defp custom_encode(_state, :channel_create_tx, tx, _tx_rec, signed_tx, _txi, _block_hash) do
    {:ok, channel_pk} = :aesc_utils.channel_pubkey(signed_tx)
    put_in(tx, ["channel_id"], Enc.encode(:channel, channel_pk))
  end

  defp custom_encode(_state, :name_claim_tx, tx, tx_rec, _signed_tx, _txi, _block_hash) do
    {:ok, name_id} = :aens.get_name_hash(:aens_claim_tx.name(tx_rec))
    put_in(tx, ["name_id"], Enc.encode(:name, name_id))
  end

  defp custom_encode(state, :name_update_tx, tx, tx_rec, _signed_tx, _txi, _block_hash) do
    tx
    |> put_in(["name"], Name.plain_name!(state, :aens_update_tx.name_hash(tx_rec)))
    |> update_in(["pointers"], &encode_pointers/1)
  end

  defp custom_encode(state, :name_transfer_tx, tx, tx_rec, _signed_tx, _txi, _block_hash),
    do: put_in(tx, ["name"], Name.plain_name!(state, :aens_transfer_tx.name_hash(tx_rec)))

  defp custom_encode(state, :name_revoke_tx, tx, tx_rec, _signed_tx, _txi, _block_hash),
    do: put_in(tx, ["name"], Name.plain_name!(state, :aens_revoke_tx.name_hash(tx_rec)))

  defp custom_encode(_state, _tx_type, tx, _tx_rec, _signed_tx, _txi, _block_hash),
    do: tx

  defp maybe_base64(bin) do
    try do
      dec = :base64.decode(bin)
      (String.valid?(dec) && dec) || bin
    rescue
      _ -> :erlang.binary_to_list(bin)
    end
  end

  defp maybe_to_list(bin) do
    if String.valid?(bin) do
      bin
    else
      :erlang.binary_to_list(bin)
    end
  end

  defp raw_to_json(x),
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
         state,
         {:name, _, active_h, expire_h, cs, us, ts, revoke, auction_tm, _owner, _prev} = n
       ) do
    %{
      active_from: active_h,
      expire_height: expire_h,
      claims: Enum.map(cs, &bi_txi_txi/1),
      updates: Enum.map(us, &bi_txi_txi/1),
      transfers: Enum.map(ts, &bi_txi_txi/1),
      revoke: (revoke && bi_txi_txi(revoke)) || nil,
      auction_timeout: auction_tm,
      pointers: Name.pointers(state, n),
      ownership: Name.ownership(state, n)
    }
  end

  defp auction_bid(
         state,
         Model.auction_bid(index: plain, expire_height: auction_end, bids: [{_, txi} | _] = bids),
         key,
         tx_fmt,
         info_fmt
       ) do
    last_bid = tx_fmt.(DbUtil.read_tx!(state, txi))
    name_ttl = Names.expire_after(auction_end)
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
        case Name.locate(state, plain) do
          {m_name, Model.InactiveName} ->
            succ = &Model.name(&1, :previous)
            Enum.map(chase(m_name, succ), &info_fmt.(name_info_to_raw_map(state, &1)))

          _ ->
            []
        end
    }
  end

  defp expand_name_auction(_state, nil), do: nil

  defp expand_name_auction(state, %{"bids" => bids_txis} = auction) do
    Map.put(auction, "bids", Enum.map(bids_txis, &Txs.fetch!(state, &1)))
  end

  defp expand_name_info(state, json) do
    json
    |> update_in(["claims"], &expand(state, &1))
    |> update_in(["updates"], &expand(state, &1))
    |> update_in(["transfers"], &expand(state, &1))
    |> update_in(["revoke"], &expand(state, &1))
  end

  defp expand(state, txis) when is_list(txis),
    do: Enum.map(txis, &to_map(state, DbUtil.read_tx!(state, &1)))

  defp expand(state, txi) when is_integer(txi),
    do: to_map(state, DbUtil.read_tx!(state, txi))

  defp expand(_state, nil),
    do: nil
end

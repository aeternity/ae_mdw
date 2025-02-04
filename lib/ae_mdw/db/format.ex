defmodule AeMdw.Db.Format do
  # credo:disable-for-this-file
  alias AeMdw.Node, as: AE
  alias :aeser_api_encoder, as: Enc

  alias AeMdw.Db.Contract, as: DbContract
  alias AeMdw.Contract
  alias AeMdw.Channels
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.InnerTx
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Log
  alias AeMdw.Names
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Util

  require Model

  import AeMdw.Util
  import AeMdw.Util.Encoding, only: [encode_account: 1]

  @type aeser_id() :: {:id, atom(), binary()}
  @max_int Util.max_int()
  @min_int Util.min_int()

  ##########

  defp bi_txi_idx_txi({{_height, _mbi}, {txi, _idx}}), do: txi

  defp txi_idx_txi({txi, _idx}), do: txi

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
      |> Map.new(fn {field, pos} ->
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

  def to_raw_map(state, Model.name(index: plain_name) = m_name, source) do
    previous = previous_list(state, plain_name)

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
      status: to_string(status),
      active: source == Model.ActiveName,
      info: name_info_to_raw_map(state, m_name),
      previous: previous
    }
  end

  @spec encode_pointers(list() | map()) :: %{iodata() => String.t()}
  def encode_pointers(pointers) when is_map(pointers) do
    Map.new(pointers, fn {key, id} -> {maybe_base64_pointer_key(key), enc_id(id)} end)
  end

  def encode_pointers(pointers) do
    Enum.map(pointers, fn
      %{"key" => key, "id" => id} -> %{"key" => maybe_base64_pointer_key(key), "id" => id}
      %{key: key, id: id} -> %{key: maybe_base64_pointer_key(key), id: id}
      {:pointer, key, id} -> %{key: maybe_base64_pointer_key(key), id: enc_id(id)}
    end)
  end

  @spec enc_id(aeser_id() | Names.raw_data_pointer() | nil) :: nil | String.t()
  def enc_id(nil), do: nil
  def enc_id({:id, _type, _pk} = id), do: Enc.encode(:id_hash, id)
  def enc_id({:data, binary}) when is_binary(binary), do: Enc.encode(:bytearray, binary)

  defp custom_raw_data(_state, :contract_create_tx, tx, tx_rec, _signed_tx, block_hash) do
    init_call_details = Contract.get_init_call_details(tx_rec, block_hash)

    update_in(tx, [:tx], fn tx_details -> Map.merge(tx_details, init_call_details) end)
  end

  defp custom_raw_data(state, :contract_call_tx, tx, tx_rec, signed_tx, block_hash) do
    contract_or_name_pk =
      tx_rec
      |> :aect_call_tx.contract_id()
      |> Db.id_pubkey()

    contract_pk = Contract.maybe_resolve_contract_pk(contract_or_name_pk, block_hash)

    txi = tx.tx_index
    fun_arg_res = AeMdw.Db.Contract.call_fun_arg_res(state, contract_pk, txi)
    call_info = format_call_info(signed_tx, contract_or_name_pk, block_hash, txi)
    call_details = Map.merge(call_info, fun_arg_res)
    update_in(tx, [:tx], &Map.merge(&1, call_details))
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

  defp format_call_info(signed_tx, contract_pk, block_hash, txi) do
    case Contract.call_rec(signed_tx, contract_pk, block_hash) do
      {:ok, call_rec} ->
        call_rec
        |> :aect_call.serialize_for_client()
        |> Map.drop(["return_value", "gas_price", "height", "contract_id", "caller_nonce"])
        |> Map.update("log", [], &Contract.stringfy_log_topics/1)

      {:error, reason} ->
        Log.error("Contract.call_rec error reason=#{inspect(reason)}, txi=#{txi}")

        %{
          call_id: nil,
          return_type: nil,
          gas_used: nil,
          log: nil
        }
    end
  end

  ##########

  def to_map(state, Model.tx(id: hash) = rec),
    do: to_map(state, rec, AE.Db.get_tx_data(hash))

  def to_map(
        state,
        Model.tx(index: index, block_index: {_kb_index, mb_index}, time: mb_time),
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
      Util.map_some(
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
    Model.int_contract_call(create_txi: create_txi, fname: fname, tx: tx) =
      State.fetch!(state, Model.IntContractCall, {call_txi, local_idx})

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

    serialized_tx = :aetx.serialize_for_client(tx)

    encoded_tx =
      case :aetx.specialize_type(tx) do
        {:contact_call_tx, _tx_rec} ->
          serialized_tx

        {tx_type, tx_rec} ->
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

  defp custom_encode(state, :channel_close_mutual_tx, tx, _tx_rec, signed_tx, _txi, _block_hash) do
    put_channel_participants(tx, state, signed_tx)
  end

  @payload_index 3

  defp custom_encode(state, :channel_close_solo_tx, tx, tx_rec, signed_tx, _txi, _block_hash) do
    tx
    |> put_channel_offchain_round(elem(tx_rec, @payload_index))
    |> put_channel_participants(state, signed_tx)
  end

  defp custom_encode(
         state,
         :channel_force_progress_tx,
         tx,
         _tx_rec,
         signed_tx,
         _txi,
         _block_hash
       ) do
    put_channel_participants(tx, state, signed_tx)
  end

  defp custom_encode(state, :channel_slash_tx, tx, tx_rec, signed_tx, _txi, _block_hash) do
    tx
    |> put_channel_offchain_round(elem(tx_rec, @payload_index))
    |> put_channel_participants(state, signed_tx)
  end

  defp custom_encode(state, :channel_snapshot_solo_tx, tx, tx_rec, signed_tx, _txi, _block_hash) do
    tx
    |> put_channel_offchain_round(:aesc_snapshot_solo_tx.payload(tx_rec))
    |> put_channel_participants(state, signed_tx)
  end

  defp custom_encode(state, :channel_settle_tx, tx, _tx_rec, signed_tx, _txi, _block_hash) do
    put_channel_participants(tx, state, signed_tx)
  end

  defp custom_encode(_state, :oracle_register_tx, tx, tx_rec, _signed_tx, _txi, _block_hash) do
    oracle_pk = :aeo_register_tx.account_pubkey(tx_rec)

    tx
    |> Map.put("oracle_id", Enc.encode(:oracle_pubkey, oracle_pk))
    |> Map.update("query_format", nil, &maybe_to_list/1)
    |> Map.update("response_format", nil, &maybe_to_list/1)
  end

  defp custom_encode(_state, :oracle_response_tx, tx, _tx_rec, _signed_tx, _txi, _block_hash),
    do: update_in(tx, ["response"], &Base.encode64/1)

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

  defp custom_encode(state, :ga_meta_tx, tx, tx_rec, _signed_tx, txi, block_hash) do
    owner_pk = :aega_meta_tx.origin(tx_rec)
    auth_id = :aega_meta_tx.auth_id(tx_rec)

    tx = add_inner_tx_details(state, :ga_meta_tx, tx, tx_rec, txi, block_hash)

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

  defp custom_encode(state, :paying_for_tx, tx, tx_rec, _signed_tx, txi, block_hash) do
    add_inner_tx_details(state, :paying_for_tx, tx, tx_rec, txi, block_hash)
  end

  defp custom_encode(state, :contract_create_tx, tx, tx_rec, _signed_tx, _txi, block_hash) do
    init_call_details = Contract.get_init_call_details(tx_rec, block_hash)

    encoded_details =
      init_call_details
      |> Map.take(["args", "return_type", "return_value"])
      |> encode_raw_values()

    aexn_type = DbContract.get_aexn_type(state, :aect_create_tx.contract_pubkey(tx_rec))

    tx
    |> Map.put("aexn_type", aexn_type)
    |> Map.merge(Map.merge(init_call_details, encoded_details))
  end

  defp custom_encode(state, :contract_call_tx, tx, tx_rec, signed_tx, txi, block_hash) do
    contract_or_name_pk =
      tx_rec
      |> :aect_call_tx.contract_id()
      |> Db.id_pubkey()

    contract_pk = Contract.maybe_resolve_contract_pk(contract_or_name_pk, block_hash)

    fun_arg_res =
      state
      |> DbContract.call_fun_arg_res(contract_pk, txi)
      |> encode_raw_values()

    call_details =
      signed_tx
      |> format_call_info(contract_or_name_pk, block_hash, txi)
      |> Map.merge(fun_arg_res)

    aexn_type = DbContract.get_aexn_type(state, contract_pk)

    tx
    |> Map.put("aexn_type", aexn_type)
    |> Map.merge(call_details)
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

  defp maybe_base64_pointer_key(key)
       when key in ["account_pubkey", "oracle_pubkey", "contract_pubkey", "channel"],
       do: key

  defp maybe_base64_pointer_key(key), do: Base.encode64(key)

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
    do: Map.new(m, fn {k, v} -> {to_string(k), map_raw_values(v, f)} end)

  def map_raw_values(l, f) when is_list(l),
    do: l |> Enum.map(&map_raw_values(&1, f))

  def map_raw_values(x, f),
    do: f.(x)

  defp encode_raw_values(x) do
    map_raw_values(x, &encode_raw_value/1)
  end

  defp encode_raw_value(value) do
    case value do
      {:tuple, list} when is_list(list) ->
        %{"tuple" => Enum.map(list, &encode_raw_values/1)}

      {:map, key, value} ->
        %{"map" => %{"key" => encode_raw_values(key), "value" => encode_raw_values(value)}}

      {:list, elements} ->
        %{"list" => encode_raw_values(elements)}

      {:word, value} ->
        %{"word" => value}

      t when is_tuple(t) ->
        t |> Tuple.to_list() |> Enum.map(&encode_raw_values/1)

      l when is_list(l) ->
        Enum.map(l, &encode_raw_values/1)

      num when is_number(num) ->
        num

      bin when is_binary(bin) ->
        if String.valid?(bin), do: bin, else: Base.encode64(bin)

      x ->
        to_string(x)
    end
  end

  defp name_info_to_raw_map(
         state,
         Model.name(
           index: plain_name,
           active: active_h,
           expire: expire_h,
           revoke: revoke,
           auction_timeout: auction_tm
         ) = name
       ) do
    cs = Name.stream_nested_resource(state, Model.NameClaim, plain_name, active_h)
    us = Name.stream_nested_resource(state, Model.NameUpdate, plain_name, active_h)
    ts = Name.stream_nested_resource(state, Model.NameTransfer, plain_name, active_h)
    {last_gen, last_micro_time} = DbUtil.last_gen_and_time!(state)

    %{
      active_from: active_h,
      expire_height: expire_h,
      approximate_expire_time: DbUtil.height_to_time(state, expire_h, last_gen, last_micro_time),
      claims: Enum.map(cs, &txi_idx_txi/1),
      updates: Enum.map(us, &txi_idx_txi/1),
      transfers: Enum.map(ts, &txi_idx_txi/1),
      revoke: (revoke && bi_txi_idx_txi(revoke)) || nil,
      auction_timeout: auction_tm,
      pointers: Name.pointers(state, name),
      ownership: Name.ownership(state, name)
    }
  end

  defp auction_bid(
         state,
         Model.auction_bid(
           index: plain_name,
           start_height: start_height,
           expire_height: auction_end
         ),
         key,
         tx_fmt,
         info_fmt
       ) do
    bids = Name.stream_nested_resource(state, Model.AuctionBidClaim, plain_name, start_height)
    {txi, _idx} = Enum.at(bids, 0)
    last_bid = tx_fmt.(DbUtil.read_tx!(state, txi))
    name_ttl = Names.expire_after(auction_end)
    keys = if Map.has_key?(last_bid, "tx"), do: ["tx", "ttl"], else: [:tx, :ttl]
    last_bid = put_in(last_bid, keys, name_ttl)
    {last_gen, last_micro_time} = DbUtil.last_gen_and_time!(state)
    auction_end_time = DbUtil.height_to_time(state, auction_end, last_gen, last_micro_time)

    %{
      key.(:name) => plain_name,
      key.(:status) => :auction,
      key.(:active) => false,
      key.(:info) => %{
        key.(:approximate_auction_end_time) => auction_end_time,
        key.(:auction_end) => auction_end,
        key.(:last_bid) => last_bid,
        key.(:bids) => Enum.map(bids, &txi_idx_txi/1)
      },
      key.(:previous) =>
        state
        |> previous_list(plain_name)
        |> Enum.map(info_fmt)
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

  defp add_inner_tx_details(state, tx_type, tx, tx_rec, txi, block_hash) do
    inner_signed_tx = InnerTx.signed_tx(tx_type, tx_rec)
    {inner_tx_type, inner_tx_rec} = inner_signed_tx |> :aetx_sign.tx() |> :aetx.specialize_type()

    if inner_tx_type != :contract_create_tx do
      update_in(tx, ["tx", "tx"], fn inner_tx ->
        custom_encode(
          state,
          inner_tx_type,
          inner_tx,
          inner_tx_rec,
          inner_signed_tx,
          txi,
          block_hash
        )
      end)
    else
      tx
    end
  end

  defp put_channel_offchain_round(tx, payload) do
    case :aesc_utils.deserialize_payload(payload) do
      {:ok, _signed_tx, offchain_tx} ->
        Map.put(tx, "round", :aesc_offchain_tx.round(offchain_tx))

      {:error, _reason} ->
        tx
    end
  end

  defp put_channel_participants(tx, state, signed_tx) do
    {:ok, channel_pk} = :aesc_utils.channel_pubkey(signed_tx)

    Model.channel(initiator: initiator_pk, responder: responder_pk) =
      Channels.fetch_record!(state, channel_pk)

    Map.merge(tx, %{
      "initiator_id" => encode_account(initiator_pk),
      "responder_id" => encode_account(responder_pk)
    })
  end

  defp previous_list(state, plain_name) do
    key_boundary = {{plain_name, @min_int}, {plain_name, @max_int}}

    state
    |> Collection.stream(Model.PreviousName, :backward, key_boundary, nil)
    |> Stream.map(&State.fetch!(state, Model.PreviousName, &1))
    |> Enum.map(fn Model.previous_name(name: name) -> name_info_to_raw_map(state, name) end)
  end
end

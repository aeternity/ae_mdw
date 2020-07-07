defmodule AeMdw.Db.Format do
  require Ex2ms

  alias AeMdw.Node, as: AE
  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Validate

  import AeMdw.Db.Name, only: [plain_name!: 1]
  import AeMdw.{Util, Db.Util}

  ##########

  def block_to_raw_map({:block, {_kbi, mbi}, _txi, hash}),
    do: record_to_map(:aec_db.get_header(hash), AE.hdr_fields((mbi == -1 && :key) || :micro))

  def block_to_map({:block, {_kbi, _mbi}, _txi, hash}) do
    header = :aec_db.get_header(hash)
    :aec_headers.serialize_for_client(header, prev_block_type(header))
  end

  ##########

  def name_info_to_map(%{} = info) do
    [{plain_name, data}] = Map.to_list(info)

    enc_pointers =
      data.pointers
      |> Enum.map(fn {key, id} -> {key, Enc.encode(:id_hash, id)} end)
      |> Enum.into(%{})

    %{
      plain_name => %{
        "name_id" => Enc.encode(:name, Validate.id!(data.name_id)),
        "claimant" => Enc.encode(:account_pubkey, Validate.id!(data.claimant)),
        "owner" => Enc.encode(:account_pubkey, Validate.id!(data.owner)),
        "claim_height" => data.claim_height,
        "expiration_height" => data.expiration_height,
        "revoked_height" => data.revoked_height,
        "claimed" => data.claimed,
        "pointers" => enc_pointers
      }
    }
  end

  ##########

  def tx_record_to_map(tx_type, tx_rec) do
    AeMdw.Node.tx_fields(tx_type)
    |> Stream.with_index(1)
    |> Enum.reduce(
      %{},
      fn {field, pos}, acc ->
        put_in(acc[field], elem(tx_rec, pos))
      end
    )
  end

  def tx_to_raw_map({:tx, _index, hash, {_kb_index, _mb_index}, _mb_time} = rec),
    do: tx_to_raw_map(rec, tx_rec_data(hash))

  def tx_to_raw_map(
        {:tx, index, hash, {kb_index, mb_index}, mb_time},
        {block_hash, type, signed_tx, tx_rec}
      ) do
    tx_map = tx_record_to_map(type, tx_rec) |> put_in([:type], type)

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

  def custom_raw_data(:contract_create_tx, tx, tx_rec, _signed_tx, _block_hash) do
    contract_pk = :aect_contracts.pubkey(:aect_contracts.new(tx_rec))
    put_in(tx, [:tx, :contract_id], :aeser_id.create(:contract, contract_pk))
  end

  def custom_raw_data(:contract_call_tx, tx, tx_rec, _signed_tx, block_hash) do
    alias AeMdw.Contract, as: C
    contract_pk = :aect_call_tx.contract_pubkey(tx_rec)
    {fun_arg_res, call_rec} = C.call_tx_info(tx_rec, contract_pk, block_hash, &C.to_map/1)

    call_info = %{
      call_id: :aect_call.id(call_rec),
      return_type: :aect_call.return_type(call_rec),
      gas_used: :aect_call.gas_used(call_rec),
      log: :aect_call.log(call_rec)
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

  def tx_to_map({:tx, _index, hash, {_kb_index, _mb_index}, _mb_time} = rec),
    do: tx_to_map(rec, tx_rec_data(hash))

  def tx_to_map(
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

    call_ser =
      Map.drop(
        :aect_call.serialize_for_client(call_rec),
        ["return_value", "gas_price", "height", "contract_id", "caller_nonce"]
      )

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
end

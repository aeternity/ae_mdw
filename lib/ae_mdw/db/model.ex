defmodule AeMdw.Db.Model do
  require Record
  require Ex2ms

  alias AeMdw.Node, as: AE
  alias :aeser_api_encoder, as: Enc

  import Record, only: [defrecord: 2]
  import AeMdw.{Util, Db.Util}

  ################################################################################

  # txs table :
  #     index = tx_index (0..), id = tx_id
  @tx_defaults [index: -1, id: <<>>, block_index: {-1, -1}, time: -1]
  defrecord :tx, @tx_defaults

  # def tx(tx_index, tx_id, block_index),
  #   do: tx(index: tx_index, id: tx_id, block_index: block_index)

  # txs block index :
  #     index = {kb_index (0..), mb_index}, tx_index = tx_index, hash = block (header) hash
  #     if tx_index == nil -> txs not synced yet on that height
  #     if tx_index == -1  -> no tx occured yet
  #     On keyblock boundary: mb_index = -1}
  @block_defaults [index: {-1, -1}, tx_index: nil, hash: <<>>]
  defrecord :block, @block_defaults

  # txs time index :
  #     index = {mb_time_msecs (0..), tx_index = (0...)},
  @time_defaults [index: {-1, -1}, unused: nil]
  defrecord :time, @time_defaults

  # txs type index  :
  #     index = {tx_type, tx_index}
  @type_defaults [index: {nil, -1}, unused: nil]
  defrecord :type, @type_defaults

  # txs fields      :
  #     index = {tx_type, tx_field_pos, object_pubkey, tx_index},
  @field_defaults [index: {nil, -1, nil, -1}, unused: nil]
  defrecord :field, @field_defaults

  # id counts       :
  #     index = {tx_type, tx_field_pos, object_pubkey}
  @id_count_defaults [index: {nil, nil, nil}, count: 0]
  defrecord :id_count, @id_count_defaults

  # object origin :
  #     index = {tx_type, pubkey, tx_index}, tx_id = tx_hash
  @origin_defaults [index: {nil, nil, nil}, tx_id: nil]
  defrecord :origin, @origin_defaults

  # we need this one to quickly locate origin keys to delete for invalidating a fork
  #
  # rev object origin :
  #     index = {tx_index, tx_type, pubkey}, unused: nil
  @rev_origin_defaults [index: {nil, nil, nil}, unused: nil]
  defrecord :rev_origin, @rev_origin_defaults


  def tables(),
    do: [
      AeMdw.Db.Model.Tx,
      AeMdw.Db.Model.Block,
      AeMdw.Db.Model.Time,
      AeMdw.Db.Model.Type,
      AeMdw.Db.Model.Field,
      AeMdw.Db.Model.IdCount,
      AeMdw.Db.Model.Origin,
      AeMdw.Db.Model.RevOrigin,
    ]

  def records(),
    do: [:tx, :block, :time, :type, :field, :origin, :rev_origin, :id_count]

  def fields(record),
    do: for({x, _} <- defaults(record), do: x)

  def record(AeMdw.Db.Model.Tx), do: :tx
  def record(AeMdw.Db.Model.Block), do: :block
  def record(AeMdw.Db.Model.Time), do: :time
  def record(AeMdw.Db.Model.Type), do: :type
  def record(AeMdw.Db.Model.Field), do: :field
  def record(AeMdw.Db.Model.IdCount), do: :id_count
  def record(AeMdw.Db.Model.Origin), do: :origin
  def record(AeMdw.Db.Model.RevOrigin), do: :rev_origin

  def table(:tx), do: AeMdw.Db.Model.Tx
  def table(:block), do: AeMdw.Db.Model.Block
  def table(:time), do: AeMdw.Db.Model.Time
  def table(:type), do: AeMdw.Db.Model.Type
  def table(:field), do: AeMdw.Db.Model.Field
  def table(:id_count), do: AeMdw.Db.Model.IdCount
  def table(:origin), do: AeMdw.Db.Model.Origin
  def table(:rev_origin), do: AeMdw.Db.Model.RevOrigin

  def defaults(:tx), do: @tx_defaults
  def defaults(:block), do: @block_defaults
  def defaults(:time), do: @time_defaults
  def defaults(:type), do: @type_defaults
  def defaults(:field), do: @field_defaults
  def defaults(:id_count), do: @id_count_defaults
  def defaults(:origin), do: @origin_defaults
  def defaults(:rev_origin), do: @rev_origin_defaults


  def write_count(model, delta) do
    total = id_count(model, :count)
    model = id_count(model, count: total + delta)
    :mnesia.write(AeMdw.Db.Model.IdCount, model, :write)
  end

  def update_count({_, _, _} = field_key, delta, empty_fn \\ fn -> :nop end) do
    case :mnesia.read(AeMdw.Db.Model.IdCount, field_key, :write) do
      [] -> empty_fn.()
      [model] -> write_count(model, delta)
    end
  end

  def incr_count({_, _, _} = field_key),
    do: update_count(field_key, 1,
          fn -> write_count(id_count(index: field_key, count: 0), 1) end)

  ##########

  def block_to_raw_map({:block, {_kbi, mbi}, _txi, hash}),
    do: record_to_map(:aec_db.get_header(hash), AE.hdr_fields((mbi == -1 && :key) || :micro))

  def block_to_map({:block, {_kbi, _mbi}, _txi, hash}) do
    header = :aec_db.get_header(hash)
    :aec_headers.serialize_for_client(header, prev_block_type(header))
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

  def custom_raw_data(_, tx, _, _, _),
    do: tx

  ##########

  def tx_to_map({:tx, _index, hash, {_kb_index, _mb_index}, _mb_time} = rec),
    do: tx_to_map(rec, tx_rec_data(hash))

  def tx_to_map(
        {:tx, index, hash, {_kb_index, mb_index}, mb_time},
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

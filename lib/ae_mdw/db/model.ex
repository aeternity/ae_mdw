defmodule AeMdw.Db.Model do
  alias :aeser_api_encoder, as: Enc

  require Record
  require Ex2ms

  import Record, only: [defrecord: 2]
  import AeMdw.{Util, Db.Util}

  ################################################################################

  # txs table :
  #     index = tx_index (0..), id = tx_id
  @tx_defaults [index: -1, id: <<>>, block_index: {-1, -1}]
  defrecord :tx, @tx_defaults

  def tx(tx_index, tx_id, block_index),
    do: tx(index: tx_index, id: tx_id, block_index: block_index)

  # txs block index :
  #     index = {kb_index (0..), mb_index}, tx_index = tx_index, hash = block (header) hash
  #     if tx_index == nil -> txs not synced yet on that height
  #     if tx_index == -1  -> no tx occured yet
  #     On keyblock boundary: mb_index = -1}
  @block_defaults [index: {-1, -1}, tx_index: nil, hash: <<>>]
  defrecord :block, @block_defaults

  # txs time index :
  #     msecs = {mb_time_msecs (0..), tx_index}, block_index = block_index
  @time_defaults [msecs: {-1, -1}, block_index: {-1, -1}]
  defrecord :time, @time_defaults

  # txs type index  :
  #     index = {tx_type, tx_index}
  @type_defaults [index: {nil, -1}, unused: nil]
  defrecord :type, @type_defaults

  # index = {tx_type, -tx_index}
  @rev_type_defaults [index: {nil, -1}, unused: nil]
  defrecord :rev_type, @rev_type_defaults

  # txs objects     :
  #     index = {tx_type, object_pubkey, tx_index}, id_tag = id_tag, role = role
  @object_defaults [index: {nil, nil, -1}, id_tag: nil, role: nil]
  defrecord :object, @object_defaults

  # index = {tx_type, object_pubkey, -tx_index}, id_tag = id_tag, role = role
  @rev_object_defaults [index: {nil, nil, -1}, id_tag: nil, role: nil]
  defrecord :rev_object, @rev_object_defaults

  # TODO:
  # contract events :
  #     index = {ct_address, event_name, tx_index, ct_address_log_local_id (0..)}, event = event
  @event_defaults [index: {"", nil, -1, -1}, event: nil]
  defrecord :event, @event_defaults
  # def event(contract_id, event_name, tx_index, ct_local_index, event),
  #   do: event([index: {contract_id, event_name, tx_index, ct_local_index}, event: event])


  def tables(),
    do: [
      AeMdw.Db.Model.Tx,
      AeMdw.Db.Model.Block,
      AeMdw.Db.Model.Time,
      AeMdw.Db.Model.Type,
      AeMdw.Db.Model.RevType,
      AeMdw.Db.Model.Object,
      AeMdw.Db.Model.RevObject,
      AeMdw.Db.Model.Event
    ]

  def records(),
    do: [:tx, :block, :time, :type, :rev_type, :object, :rev_object, :event]

  def fields(record),
    do: for({x, _} <- defaults(record), do: x)

  def record(AeMdw.Db.Model.Tx), do: :tx
  def record(AeMdw.Db.Model.Block), do: :block
  def record(AeMdw.Db.Model.Time), do: :time
  def record(AeMdw.Db.Model.Type), do: :type
  def record(AeMdw.Db.Model.RevType), do: :rev_type
  def record(AeMdw.Db.Model.Object), do: :object
  def record(AeMdw.Db.Model.RevObject), do: :rev_object
  def record(AeMdw.Db.Model.Event), do: :event

  def table(:tx), do: AeMdw.Db.Model.Tx
  def table(:block), do: AeMdw.Db.Model.Block
  def table(:time), do: AeMdw.Db.Model.Time
  def table(:type), do: AeMdw.Db.Model.Type
  def table(:rev_type), do: AeMdw.Db.Model.RevType
  def table(:object), do: AeMdw.Db.Model.Object
  def table(:rev_object), do: AeMdw.Db.Model.RevObject
  def table(:event), do: AeMdw.Db.Model.Event

  def defaults(:tx), do: @tx_defaults
  def defaults(:block), do: @block_defaults
  def defaults(:time), do: @time_defaults
  def defaults(:type), do: @type_defaults
  def defaults(:rev_type), do: @rev_type_defaults
  def defaults(:object), do: @object_defaults
  def defaults(:rev_object), do: @rev_object_defaults
  def defaults(:event), do: @event_defaults

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

  def to_raw_map({:tx, index, hash, {kb_index, mb_index}}) do
    {_, _, db_stx} = one!(:mnesia.dirty_read(:aec_signed_tx, hash))
    aec_signed_tx = :aetx_sign.from_db_format(db_stx)
    {type, rec} = :aetx.specialize_type(:aetx_sign.tx(aec_signed_tx))

    %{
      block_hash: block(read_block!({kb_index, mb_index}), :hash),
      height: kb_index,
      mb_index: mb_index,
      hash: hash,
      type: type,
      index: index,
      signatures: :aetx_sign.signatures(aec_signed_tx),
      tx: tx_record_to_map(type, rec)
    }
  end

  def to_map({:tx, index, hash, {kb_index, mb_index}}) do
    raw = to_raw_map({:tx, index, hash, {kb_index, mb_index}})

    raw
    |> update_in([:block_hash], &Enc.encode(:micro_block_hash, &1))
    |> update_in([:hash], &Enc.encode(:tx_hash, &1))
    |> update_in([:signatures], fn ts -> Enum.map(ts, &Enc.encode(:signature, &1)) end)
    |> update_in([:tx], &encode_ids(&1, raw.type))
    |> put_in([:tx, :type], AeMdwWeb.Util.to_user_tx_type(raw.type))
    |> custom_encode
  end

  def encode_ids(tx_map, type) do
    AeMdw.Node.tx_ids(type)
    |> Enum.reduce(tx_map, fn {k, _}, tx -> update_in(tx[k], &encode_id/1) end)
  end


  ################################################################################

  def custom_encode(%{type: :name_update_tx} = tx),
    do: update_in(tx.tx.pointers, &encode_name_pointer/1)
  def custom_encode(%{type: :contract_call_tx} = tx) do
    tx
    |> update_in([:tx, :call_data], &Enc.encode(:contract_bytearray, &1))
    |> update_in([:tx, :call_origin], &Enc.encode(:account_pubkey, &1))
  end
  def custom_encode(%{type: :contract_create_tx} = tx) do
    tx
    |> update_in([:tx, :call_data], &Enc.encode(:contract_bytearray, &1))
    |> update_in([:tx, :code], &Enc.encode(:contract_bytearray, &1))
  end
  def custom_encode(%{type: :channel_create_tx} = tx),
    do: update_in(tx.tx.state_hash, &Enc.encode(:block_state_hash, &1))
  def custom_encode(%{type: :channel_deposit_tx} = tx),
    do: update_in(tx.tx.state_hash, &Enc.encode(:block_state_hash, &1))
  def custom_encode(%{type: :channel_force_progress_tx} = tx) do
    tx
    |> update_in([:tx, :state_hash], &Enc.encode(:block_state_hash, &1))
    |> update_in([:tx, :payload], &Enc.encode(:transaction, &1))
    |> update_in([:tx, :update], &:aesc_offchain_update.for_client(&1))
    |> update_in([:tx, :offchain_trees], &Enc.encode(:state_trees, :aec_trees.serialize_to_binary(&1)))
  end
  def custom_encode(%{type: :channel_close_solo_tx} = tx) do
    tx
    |> update_in([:tx, :payload], &Enc.encode(:transaction, &1))
    |> update_in([:tx, :poi], &Enc.encode(:poi, :aec_trees.serialize_poi(&1)))
  end
  def custom_encode(%{type: :channel_slash_tx} = tx) do
    tx
    |> update_in([:tx, :payload], &Enc.encode(:transaction, &1))
    |> update_in([:tx, :poi], &Enc.encode(:poi, :aec_trees.serialize_poi(&1)))
  end
  def custom_encode(%{type: :channel_snapshot_solo_tx} = tx),
    do: update_in(tx.tx.payload, &Enc.encode(:transaction, &1))
  def custom_encode(%{type: :oracle_register_tx} = tx),
    do: update_in(tx.tx.oracle_ttl, &encode_ttl(&1, tx.height))
  def custom_encode(%{type: :oracle_extend_tx} = tx),
    do: update_in(tx.tx.oracle_ttl, &encode_ttl(&1, tx.height))
  def custom_encode(%{type: :oracle_query_tx, height: height} = tx) do
    tx
    |> update_in([:tx, :query_ttl], &encode_ttl(&1, height))
    |> update_in([:tx, :response_ttl], &encode_ttl(&1, height))
  end
  def custom_encode(%{type: :oracle_response_tx} = tx) do
    tx
    |> update_in([:tx, :response_ttl], &encode_ttl(&1, tx.height))
    |> update_in([:tx, :query_id], &Enc.encode(:oracle_query_id, &1))
    |> update_in([:tx, :response], &maybe_base64/1)
  end
  def custom_encode(%{type: :ga_attach_tx} = tx) do
    tx
    |> update_in([:tx, :auth_fun], &encode16_lowercased/1)
    |> update_in([:tx, :call_data], &Enc.encode(:contract_bytearray, &1))
    |> update_in([:tx, :code], &Enc.encode(:contract_bytearray, &1))
  end
  def custom_encode(%{type: :ga_meta_tx} = tx) do
    tx
    |> update_in([:tx, :auth_data], &Enc.encode(:contract_bytearray, &1))
    |> update_in([:tx, :tx], fn aec_signed_tx ->
      {type, rec} = :aetx.specialize_type(:aetx_sign.tx(aec_signed_tx))
      nested_tx =
        tx_record_to_map(type, rec)
        |> encode_ids(type)
        |> put_in([:type], AeMdwWeb.Util.to_user_tx_type(type))
      %{tx: nested_tx}
    end)
  end
  def custom_encode(tx),
    do: tx


  def encode_id(xs) when is_list(xs),
    do: xs |> Enum.map(&Enc.encode(:id_hash, &1))

  def encode_id({:id, _, _} = x),
    do: Enc.encode(:id_hash, x)

  def encode_name_pointer(ptrs) when is_list(ptrs),
    do: ptrs |> Enum.map(&encode_name_pointer/1)

  def encode_name_pointer(ptr),
    do: %{key: :aens_pointer.key(ptr), id: encode_id(:aens_pointer.id(ptr))}

  def encode_ttl({:delta, diff}, height),
    do: height + diff
  def encode_ttl({:block, height}, _),
    do: height

  def encode16_lowercased(bin),
    do: "0x" <> (bin |> Base.encode16 |> String.downcase)

  def maybe_base64(bin) do
    try do
      :base64.decode(bin)
    rescue
      _ -> bin
    end
  end
end

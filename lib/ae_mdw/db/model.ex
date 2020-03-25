defmodule AeMdw.Db.Model do
  alias :aeser_api_encoder, as: Enc

  require Record
  require Ex2ms

  import Record, only: [defrecord: 2]
  import AeMdw.{Sigil, Util, Db.Util}

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

  # meta table, storing sync progress and other info
  # TODO: replace it with fastglobal lib
  @meta_defaults [key: nil, val: nil]
  defrecord :meta, @meta_defaults

  def get_meta!(key),
    do: get_meta(key) |> map_ok!(& &1)

  def get_meta(key),
    do: ~t[meta] |> :mnesia.dirty_read(key) |> map_one(&{:ok, meta(&1, :val)})

  def set_meta(key, val),
    do: ~t[meta] |> :mnesia.dirty_write(meta(key: key, val: val))

  def del_meta(key),
    do: ~t[meta] |> :mnesia.dirty_delete(key)

  def list_meta(),
    do:
      ~t[meta]
      |> :mnesia.dirty_select(
        Ex2ms.fun do
          {:meta, k, v} -> {k, v}
        end
      )

  def tables(),
    do: [
      AeMdw.Db.Model.Tx,
      AeMdw.Db.Model.Block,
      AeMdw.Db.Model.Time,
      AeMdw.Db.Model.Type,
      AeMdw.Db.Model.RevType,
      AeMdw.Db.Model.Object,
      AeMdw.Db.Model.RevObject,
      AeMdw.Db.Model.Event,
      AeMdw.Db.Model.Meta
    ]

  def records(),
    do: [:tx, :block, :time, :type, :rev_type, :object, :rev_object, :event, :meta]

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
  def record(AeMdw.Db.Model.Meta), do: :meta

  def table(:tx), do: AeMdw.Db.Model.Tx
  def table(:block), do: AeMdw.Db.Model.Block
  def table(:time), do: AeMdw.Db.Model.Time
  def table(:type), do: AeMdw.Db.Model.Type
  def table(:rev_type), do: AeMdw.Db.Model.RevType
  def table(:object), do: AeMdw.Db.Model.Object
  def table(:rev_object), do: AeMdw.Db.Model.RevObject
  def table(:event), do: AeMdw.Db.Model.Event
  def table(:meta), do: AeMdw.Db.Model.Meta

  def defaults(:tx), do: @tx_defaults
  def defaults(:block), do: @block_defaults
  def defaults(:time), do: @time_defaults
  def defaults(:type), do: @type_defaults
  def defaults(:rev_type), do: @rev_type_defaults
  def defaults(:object), do: @object_defaults
  def defaults(:rev_object), do: @rev_object_defaults
  def defaults(:event), do: @event_defaults
  def defaults(:meta), do: @meta_defaults

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
      tx: AeMdw.Node.tx_to_map(type, rec)
    }
  end

  def to_map({:tx, index, hash, {kb_index, mb_index}}) do
    raw = to_raw_map({:tx, index, hash, {kb_index, mb_index}})

    raw
    |> update_in([:block_hash], &Enc.encode(:micro_block_hash, &1))
    |> update_in([:hash], &Enc.encode(:tx_hash, &1))
    |> update_in([:signatures], fn ts -> Enum.map(ts, &Enc.encode(:signature, &1)) end)
    |> update_in(
      [:tx],
      fn tx ->
        AeMdw.Node.tx_ids(raw.type)
        |> Enum.reduce(tx, fn {k, _}, tx -> update_in(tx[k], &encode_id/1) end)
      end
    )
    |> put_in([:tx, :type], AeMdwWeb.Util.to_user_tx_type(raw.type))
  end

  def encode_id(xs) when is_list(xs),
    do: xs |> Enum.map(&Enc.encode(:id_hash, &1))

  def encode_id({:id, _, _} = x),
    do: Enc.encode(:id_hash, x)
end

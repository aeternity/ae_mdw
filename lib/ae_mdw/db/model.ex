defmodule AeMdw.Db.Model do
  require Record
  require Ex2ms

  import Record, only: [defrecord: 2]
  import AeMdw.{Util, Sigil}

  # txs table :
  #     index = tx_index (0..), id = tx_id
  @tx_defaults [index: -1, id: <<>>, block_index: {-1, -1}]
  defrecord :tx, @tx_defaults

  def tx(tx_index, tx_id, block_index),
    do: tx(index: tx_index, id: tx_id, block_index: block_index)

  # txs block index :
  #     index = {kb_index (0..), mb_index}, tx_index = tx_index, hash = block (header) hash
  #     On keyblock boundary - mb_index = -1, tx_index = -1}
  @block_defaults [index: {-1, -1}, tx_index: -1, hash: <<>>]
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

  def index(:block, tx_index, %{block_index: {key_index, micro_index}, block_hash: hash}),
    do: block(index: {key_index, micro_index}, tx_index: tx_index, hash: hash)

  def index(:time, tx_index, %{block_index: {kb_index, mb_index}, time: msecs}),
    do: time(msecs: {msecs, tx_index}, block_index: {kb_index, mb_index})

  def index(:type, tx_index, %{type: tx_type}),
    do: type(index: {tx_type, tx_index})

  def index(:rev_type, tx_index, %{type: tx_type}),
    do: rev_type(index: {tx_type, -tx_index})

  def index(:object, tx_index, %{type: tx_type, object: {id_tag, object_pubkey}, role: role}),
    do: object(index: {tx_type, object_pubkey, tx_index}, id_tag: id_tag, role: role)

  def index(:rev_object, tx_index, %{type: tx_type, object: {id_tag, object_pk}, role: role}),
    do: rev_object(index: {tx_type, object_pk, -tx_index}, id_tag: id_tag, role: role)

  # meta table, storing sync progress and other info
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

  def to_map({:tx, tx_index, tx_hash, {kb_index, mb_index}}) do
    {:aec_signed_tx, _, db_stx} = one!(:mnesia.dirty_read(:aec_signed_tx, tx_hash))

    {tx_type, tx_rec} =
      db_stx
      |> :aetx_sign.from_db_format()
      |> :aetx_sign.tx()
      |> :aetx.specialize_type()

    tx_map = AeMdw.Node.tx_to_map(tx_type, tx_rec)

    %{
      tx_hash: tx_hash,
      tx_index: tx_index,
      tx_type: tx_type,
      height: kb_index,
      mb_index: mb_index,
      tx: tx_map
    }
  end

  # def pubkey_tx_types() do
  #   :mnesia.async_dirty(
  #     fn ->
  #       :mnesia.foldl(
  #         fn {:object, {tx_type, pk, _}, _, _}, acc ->
  #           f = fn nil -> :gb_sets.from_list([tx_type])
  #                  set -> :gb_sets.add(tx_type, set)
  #               end
  #           update_in(acc[pk], f)
  #         end,
  #         %{},
  #         ~t[object]
  #       )
  #     end
  #   )
  # end
end

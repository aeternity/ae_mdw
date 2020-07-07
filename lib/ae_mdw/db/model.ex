defmodule AeMdw.Db.Model do
  require Record
  require Ex2ms

  import Record, only: [defrecord: 2]
  import AeMdw.{Util, Db.Util}

  ################################################################################

  # txs block index :
  #     index = {kb_index (0..), mb_index}, tx_index = tx_index, hash = block (header) hash
  #     if tx_index == nil -> txs not synced yet on that height
  #     if tx_index == -1  -> no tx occured yet
  #     On keyblock boundary: mb_index = -1}
  @block_defaults [index: {-1, -1}, tx_index: nil, hash: <<>>]
  defrecord :block, @block_defaults

  # txs table :
  #     index = tx_index (0..), id = tx_id
  @tx_defaults [index: -1, id: <<>>, block_index: {-1, -1}, time: -1]
  defrecord :tx, @tx_defaults

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
  #     index = {tx_index, tx_type, pubkey}
  @rev_origin_defaults [index: {nil, nil, nil}, unused: nil]
  defrecord :rev_origin, @rev_origin_defaults

  # name pointee : (updated when name_update_tx changes pointers)
  #     index = {pointer_val, tx_index, pointer_key}
  @name_pointee_defaults [index: {nil, nil, nil}, unused: nil]
  defrecord :name_pointee, @name_pointee_defaults

  # rev name pointee :
  #     index = {tx_index, pointer_val, pointer_key}
  @rev_name_pointee_defaults [index: {nil, nil, nil}, unused: nil]
  defrecord :rev_name_pointee, @rev_name_pointee_defaults

  # name auction :
  #     index = {expiration_height, name_hash}, name_rec
  @name_auction_defaults [index: {nil, nil}, name_rec: nil]
  defrecord :name_auction, @name_auction_defaults

  # name lookup:
  #     index = {name_hash, claim_height},
  #     name = plain name, expire = height, revoke = height,
  #     auction = nil | [tx_index]
  @name_defaults [index: {nil, nil}, name: nil, expire: nil, revoke: nil, auction: nil]
  defrecord :name, @name_defaults

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
      AeMdw.Db.Model.NamePointee,
      AeMdw.Db.Model.RevNamePointee,
      AeMdw.Db.Model.NameAuction,
      AeMdw.Db.Model.Name
    ]

  def records(),
    do: [
      :tx,
      :block,
      :time,
      :type,
      :field,
      :id_count,
      :origin,
      :rev_origin,
      :name_pointee,
      :rev_name_pointee,
      :name_auction,
      :name
    ]

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
  def record(AeMdw.Db.Model.NamePointee), do: :name_pointee
  def record(AeMdw.Db.Model.RevNamePointee), do: :rev_name_pointee
  def record(AeMdw.Db.Model.NameAuction), do: :name_auction
  def record(AeMdw.Db.Model.Name), do: :name

  def table(:tx), do: AeMdw.Db.Model.Tx
  def table(:block), do: AeMdw.Db.Model.Block
  def table(:time), do: AeMdw.Db.Model.Time
  def table(:type), do: AeMdw.Db.Model.Type
  def table(:field), do: AeMdw.Db.Model.Field
  def table(:id_count), do: AeMdw.Db.Model.IdCount
  def table(:origin), do: AeMdw.Db.Model.Origin
  def table(:rev_origin), do: AeMdw.Db.Model.RevOrigin
  def table(:name_pointee), do: AeMdw.Db.Model.NamePointee
  def table(:rev_name_pointee), do: AeMdw.Db.Model.RevNamePointee
  def table(:name_auction), do: AeMdw.Db.Model.NameAuction
  def table(:name), do: AeMdw.Db.Model.Name

  def defaults(:tx), do: @tx_defaults
  def defaults(:block), do: @block_defaults
  def defaults(:time), do: @time_defaults
  def defaults(:type), do: @type_defaults
  def defaults(:field), do: @field_defaults
  def defaults(:id_count), do: @id_count_defaults
  def defaults(:origin), do: @origin_defaults
  def defaults(:rev_origin), do: @rev_origin_defaults
  def defaults(:name_pointee), do: @name_pointee_defaults
  def defaults(:rev_name_pointee), do: @rev_name_pointee_defaults
  def defaults(:name_auction), do: @name_auction_defaults
  def defaults(:name), do: @name_defaults

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
    do: update_count(field_key, 1, fn -> write_count(id_count(index: field_key, count: 0), 1) end)
end

defmodule AeMdw.Db.Model do
  require Record
  require Ex2ms

  import Record, only: [defrecord: 2]

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

  # plain name:
  #     index = name_hash, plain = plain name
  @plain_name_defaults [index: nil, value: nil]
  defrecord :plain_name, @plain_name_defaults

  # auction bid:
  #     index = {plain_name, {block_index, txi}, expire_height = height, owner = pk, prev_bids = []}
  @auction_bid_defaults [index: {nil, {{nil, nil}, nil}, nil, nil, nil}, unused: nil]
  defrecord :auction_bid, @auction_bid_defaults

  # in 3 tables: auction_expiration, name_expiration, inactive_name_expiration
  #
  # expiration:
  #     index = {expire_height, plain_name | oracle_pk}, value: any
  @expiration_defaults [index: {nil, nil}, value: nil]
  defrecord :expiration, @expiration_defaults

  # in 2 tables: active_name, inactive_name
  #
  # name:
  #     index = plain_name,
  #     active = height                    #
  #     expire = height                    #
  #     claims =  [{block_index, txi}]     #
  #     updates = [{block_index, txi}]     #
  #     transfers = [{block_index, txi}]   #
  #     revoke = {block_index, txi} | nil  #
  #     auction_timeout = int              # 0 if not auctioned
  #     owner = pubkey                     #
  #     previous = m_name | nil            # previus epoch of the same name
  #
  #     (other info (pointers, owner) is from looking up last update tx)
  @name_defaults [
    index: nil,
    active: nil,
    expire: nil,
    claims: [],
    updates: [],
    transfers: [],
    revoke: nil,
    auction_timeout: 0,
    owner: nil,
    previous: nil
  ]
  defrecord :name, @name_defaults

  # owner: (updated via name claim/transfer)
  #     index = {pubkey, entity},
  @owner_defaults [index: nil, unused: nil]
  defrecord :owner, @owner_defaults

  # pointee : (updated when name_update_tx changes pointers)
  #     index = {pointer_val, {block_index, txi}, pointer_key}
  @pointee_defaults [index: {nil, {{nil, nil}, nil}, nil}, unused: nil]
  defrecord :pointee, @pointee_defaults

  # in 2 tables: active_oracle, inactive_oracle
  #
  # oracle:
  #     index: pubkey
  #     active: height
  #     expire: height
  #     register: {block_index, txi}
  #     extends: [{block_index, txi}]
  #     previous: m_oracle | nil
  #
  #     (other details come from MPT lookup)
  @oracle_defaults [
    index: nil,
    active: nil,
    expire: nil,
    register: nil,
    extends: [],
    previous: nil
  ]
  defrecord :oracle, @oracle_defaults

  ################################################################################

  def tables(),
    do: Enum.concat([chain_tables(), name_tables(), oracle_tables()])

  def chain_tables() do
    [
      AeMdw.Db.Model.Tx,
      AeMdw.Db.Model.Block,
      AeMdw.Db.Model.Time,
      AeMdw.Db.Model.Type,
      AeMdw.Db.Model.Field,
      AeMdw.Db.Model.IdCount,
      AeMdw.Db.Model.Origin,
      AeMdw.Db.Model.RevOrigin
    ]
  end

  def name_tables() do
    [
      AeMdw.Db.Model.PlainName,
      AeMdw.Db.Model.AuctionBid,
      AeMdw.Db.Model.Pointee,
      AeMdw.Db.Model.AuctionExpiration,
      AeMdw.Db.Model.ActiveNameExpiration,
      AeMdw.Db.Model.InactiveNameExpiration,
      AeMdw.Db.Model.ActiveName,
      AeMdw.Db.Model.InactiveName,
      AeMdw.Db.Model.AuctionOwner,
      AeMdw.Db.Model.ActiveNameOwner
    ]
  end

  def oracle_tables() do
    [
      AeMdw.Db.Model.ActiveOracleExpiration,
      AeMdw.Db.Model.InactiveOracleExpiration,
      AeMdw.Db.Model.ActiveOracle,
      AeMdw.Db.Model.InactiveOracle
    ]
  end

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
      :plain_name,
      :auction_bid,
      :expiration,
      :name,
      :owner,
      :pointee,
      :oracle
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
  def record(AeMdw.Db.Model.PlainName), do: :plain_name
  def record(AeMdw.Db.Model.AuctionBid), do: :auction_bid
  def record(AeMdw.Db.Model.Pointee), do: :pointee
  def record(AeMdw.Db.Model.AuctionExpiration), do: :expiration
  def record(AeMdw.Db.Model.ActiveNameExpiration), do: :expiration
  def record(AeMdw.Db.Model.InactiveNameExpiration), do: :expiration
  def record(AeMdw.Db.Model.ActiveName), do: :name
  def record(AeMdw.Db.Model.InactiveName), do: :name
  def record(AeMdw.Db.Model.AuctionOwner), do: :owner
  def record(AeMdw.Db.Model.ActiveNameOwner), do: :owner
  def record(AeMdw.Db.Model.ActiveOracleExpiration), do: :expiration
  def record(AeMdw.Db.Model.InactiveOracleExpiration), do: :expiration
  def record(AeMdw.Db.Model.ActiveOracle), do: :oracle
  def record(AeMdw.Db.Model.InactiveOracle), do: :oracle

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
  def defaults(:plain_name), do: @plain_name_defaults
  def defaults(:auction_bid), do: @auction_bid_defaults
  def defaults(:pointee), do: @pointee_defaults
  def defaults(:expiration), do: @expiration_defaults
  def defaults(:name), do: @name_defaults
  def defaults(:owner), do: @owner_defaults
  def defaults(:oracle), do: @oracle_defaults

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

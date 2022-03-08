defmodule AeMdw.Db.Model do
  @moduledoc """
  Database database model records.
  """
  alias AeMdw.Blocks
  alias AeMdw.Contract
  alias AeMdw.Database
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  require Record
  require Ex2ms

  import Record, only: [defrecord: 2]

  ################################################################################

  # index is timestamp (daylight saving order should be handle case by case)
  @type async_tasks_record :: record(:async_tasks, index: {integer(), atom()}, args: list())
  @async_tasks_defaults [index: {-1, nil}, args: nil]
  defrecord :async_tasks, @async_tasks_defaults

  # index is version like 20210826171900 in 20210826171900_reindex_remote_logs.ex
  @migrations_defaults [index: -1, inserted_at: nil]
  defrecord :migrations, @migrations_defaults

  # txs block index :
  #     index = {kb_index (0..), mb_index}, tx_index = tx_index, hash = block (header) hash
  #     if tx_index == nil -> txs not synced yet on that height
  #     if tx_index == -1  -> no tx occured yet
  #     On keyblock boundary: mb_index = -1}
  @block_defaults [index: {-1, -1}, tx_index: nil, hash: <<>>]
  defrecord :block, @block_defaults

  @type block ::
          record(:block,
            index: Blocks.block_index(),
            tx_index: Txs.txi() | nil | -1,
            hash: Blocks.block_hash()
          )

  # txs table :
  #     index = tx_index (0..), id = tx_id, block_index = {kbi, mbi}
  @tx_defaults [index: -1, id: <<>>, block_index: {-1, -1}, time: -1]
  defrecord :tx, @tx_defaults

  @type tx ::
          record(:tx,
            index: Txs.txi(),
            id: Txs.tx_hash(),
            block_index: Blocks.block_index(),
            time: Blocks.time()
          )

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

  @type oracle() ::
          record(:oracle,
            index: Db.pubkey(),
            active: Blocks.height(),
            expire: Blocks.height(),
            register: {Blocks.block_index(), Txs.txi()},
            extends: [{Blocks.block_index(), Txs.txi()}],
            previous: oracle() | nil
          )

  # AEX9 balance:
  #     index = {contract_pk, account_pk}
  #     block_index = {kbi, mbi}
  #     amounts: float
  @type aex9_balance ::
          record(:aex9_balance,
            index: {Db.pubkey(), Db.pubkey()},
            block_index: Blocks.block_index(),
            amount: float()
          )
  @aex9_balance_defaults [index: {<<>>, <<>>}, block_index: {-1, -1}, amount: nil]
  defrecord :aex9_balance, @aex9_balance_defaults

  # AEX9 contract:
  #     index: {name, symbol, txi, decimals}
  @aex9_contract_defaults [
    index: {nil, nil, nil, nil},
    unused: nil
  ]
  defrecord :aex9_contract, @aex9_contract_defaults

  # AEX9 contract symbol:
  #     index: {symbol, name, txi, decimals}
  @aex9_contract_symbol_defaults [
    index: {nil, nil, nil, nil},
    unused: nil
  ]
  defrecord :aex9_contract_symbol, @aex9_contract_symbol_defaults

  # rev AEX9 contract:
  #     index: {txi, name, symbol, decimals}
  @rev_aex9_contract_defaults [
    index: {nil, nil, nil, nil},
    unused: nil
  ]
  defrecord :rev_aex9_contract, @rev_aex9_contract_defaults

  # AEX9 contract pubkey:
  #     index: pubkey
  #     txi: txi
  @aex9_contract_pubkey_defaults [
    index: nil,
    txi: nil
  ]
  defrecord :aex9_contract_pubkey, @aex9_contract_pubkey_defaults

  # contract call:
  #     index: {create txi, call txi}
  #     fun: ""
  #     args: []
  #     result: :ok
  #     return: nil
  @contract_call_defaults [
    index: {-1, -1},
    fun: nil,
    args: nil,
    result: nil,
    return: nil
  ]
  defrecord :contract_call, @contract_call_defaults

  # contract log:
  #     index: {create txi, call txi, event hash, log idx}
  #     ext_contract: nil || ext_contract_pk
  #     args: []
  #     data: ""
  @contract_log_defaults [
    index: {-1, -1, nil, -1},
    ext_contract: nil,
    args: [],
    data: ""
  ]
  defrecord :contract_log, @contract_log_defaults

  # data contract log:
  #     index: {data, call txi, create txi, event hash, log idx}
  @data_contract_log_defaults [
    index: {nil, -1, -1, nil, -1},
    unused: nil
  ]
  defrecord :data_contract_log, @data_contract_log_defaults

  # evt contract log:
  #     index: {event hash, call txi, create txi, log idx}
  @evt_contract_log_defaults [
    index: {nil, -1, -1, -1},
    unused: nil
  ]
  defrecord :evt_contract_log, @evt_contract_log_defaults

  # idx contract log:
  #     index: {call txi, create txi, event hash, log idx}
  @idx_contract_log_defaults [
    index: {-1, -1, nil, -1},
    unused: nil
  ]
  defrecord :idx_contract_log, @idx_contract_log_defaults

  # aex9 transfer:
  #    index: {from pk, call txi, to pk, amount, log idx}
  @aex9_transfer_defaults [
    index: {nil, -1, nil, -1, -1},
    unused: nil
  ]
  defrecord :aex9_transfer, @aex9_transfer_defaults

  # rev aex9 transfer:
  #    index: {to pk, call txi, from pk, amount, log idx}
  @rev_aex9_transfer_defaults [
    index: {nil, -1, nil, -1, -1},
    unused: nil
  ]
  defrecord :rev_aex9_transfer, @rev_aex9_transfer_defaults

  # aex9 pair transfer:
  #    index: {from pk, to pk, call txi, amount, log idx}
  @aex9_pair_transfer_defaults [
    index: {nil, nil, -1, -1, -1},
    unused: nil
  ]
  defrecord :aex9_pair_transfer, @aex9_pair_transfer_defaults

  # idx aex9 transfer:
  #    index: {call txi, log idx, from pk, to pk, amount}
  @idx_aex9_transfer_defaults [
    index: {-1, -1, nil, nil, -1},
    unused: nil
  ]
  defrecord :idx_aex9_transfer, @idx_aex9_transfer_defaults

  # aex9 account presence:
  #    index: {account pk, create or call txi, contract pk}
  @aex9_account_presence_defaults [
    index: {nil, -1, nil},
    unused: nil
  ]
  defrecord :aex9_account_presence, @aex9_account_presence_defaults

  # idx_aex9_account_presence:
  #    index: {create or call txi, account pk, contract pk}
  @idx_aex9_account_presence_defaults [
    index: {-1, nil, nil},
    unused: nil
  ]
  defrecord :idx_aex9_account_presence, @idx_aex9_account_presence_defaults

  # int_contract_call:
  #    index: {call txi, local idx}
  @int_contract_call_defaults [
    index: {-1, -1},
    create_txi: -1,
    fname: "",
    tx: {}
  ]
  defrecord :int_contract_call, @int_contract_call_defaults

  @type int_contract_call ::
          record(:int_contract_call,
            index: {Txs.txi(), Contract.local_idx()},
            create_txi: Txs.txi(),
            fname: Contract.fname(),
            tx: Node.aetx()
          )

  # grp_int_contract_call:
  #    index: {create txi, call txi, local idx}
  @grp_int_contract_call_defaults [
    index: {-1, -1, -1},
    unused: nil
  ]
  defrecord :grp_int_contract_call, @grp_int_contract_call_defaults

  # fname_int_contract_call:
  #    index: {fname, call txi, local idx}
  @fname_int_contract_call_defaults [
    index: {"", -1, -1},
    unused: nil
  ]
  defrecord :fname_int_contract_call, @fname_int_contract_call_defaults

  # fname_grp_int_contract_call:
  #    index: {fname, create txi, call txi, local idx}
  @fname_grp_int_contract_call_defaults [
    index: {"", -1, -1, -1},
    unused: nil
  ]
  defrecord :fname_grp_int_contract_call, @fname_grp_int_contract_call_defaults

  ##
  # id_int_contract_call:
  #    index: {id pk, id pos, call txi, local idx}
  @id_int_contract_call_defaults [
    index: {<<>>, -1, -1, -1},
    unused: nil
  ]
  defrecord :id_int_contract_call, @id_int_contract_call_defaults

  # grp_id_int_contract_call:
  #    index: {create txi, id pk, id pos, call txi, local idx}
  @grp_id_int_contract_call_defaults [
    index: {-1, <<>>, -1, -1, -1},
    unused: nil
  ]
  defrecord :grp_id_int_contract_call, @grp_id_int_contract_call_defaults

  # id_fname_int_contract_call:
  #    index: {id pk, fname, id pos, call txi, local idx}
  @id_fname_int_contract_call_defaults [
    index: {<<>>, "", -1, -1, -1},
    unused: nil
  ]
  defrecord :id_fname_int_contract_call, @id_fname_int_contract_call_defaults

  # grp_id_fname_int_contract_call:
  #    index: {create txi, id pk, fname, id pos, call txi, local idx}
  @grp_id_fname_int_contract_call_defaults [
    index: {-1, <<>>, "", -1, -1, -1},
    unused: nil
  ]
  defrecord :grp_id_fname_int_contract_call, @grp_id_fname_int_contract_call_defaults

  # int_transfer_tx
  @int_transfer_tx_defaults [
    # {{height, -1 (generation related transfer OR >=0 txi (tx related transfer)}, kind, target, ref txi}
    index: {{-1, -1}, nil, <<>>, -1},
    amount: 0
  ]
  defrecord :int_transfer_tx, @int_transfer_tx_defaults

  # kind_int_transfer_tx
  @kind_int_transfer_tx_defaults [
    index: {nil, {-1, -1}, <<>>, -1},
    unused: nil
  ]
  defrecord :kind_int_transfer_tx, @kind_int_transfer_tx_defaults

  # target_kind_int_transfer_tx
  @target_kind_int_transfer_tx_defaults [
    index: {<<>>, <<>>, {-1, -1}, -1},
    unused: nil
  ]
  defrecord :target_kind_int_transfer_tx, @target_kind_int_transfer_tx_defaults

  # statistics
  @delta_stat_defaults [
    # height
    index: 0,
    auctions_started: 0,
    names_activated: 0,
    names_expired: 0,
    names_revoked: 0,
    oracles_registered: 0,
    oracles_expired: 0,
    contracts_created: 0,
    block_reward: 0,
    dev_reward: 0
  ]
  defrecord :delta_stat, @delta_stat_defaults

  @type delta_stat ::
          record(:delta_stat,
            index: Blocks.height(),
            auctions_started: integer(),
            names_activated: integer(),
            names_expired: integer(),
            names_revoked: integer(),
            oracles_registered: integer(),
            oracles_expired: integer(),
            contracts_created: integer(),
            block_reward: integer(),
            dev_reward: integer()
          )

  # summarized statistics
  @total_stat_defaults [
    # height
    index: 0,
    block_reward: 0,
    dev_reward: 0,
    total_supply: 0,
    active_auctions: 0,
    active_names: 0,
    inactive_names: 0,
    active_oracles: 0,
    inactive_oracles: 0,
    contracts: 0
  ]
  defrecord :total_stat, @total_stat_defaults

  @type total_stat ::
          record(:total_stat,
            index: Blocks.height(),
            block_reward: integer(),
            dev_reward: integer(),
            total_supply: integer(),
            active_auctions: integer(),
            active_names: integer(),
            inactive_names: integer(),
            active_oracles: integer(),
            inactive_oracles: integer(),
            contracts: integer()
          )

  ################################################################################

  # starts with only chain_tables and add them progressively by groups
  @spec column_families() :: list(atom())
  def column_families do
    # next candidate chain_tables()
    [
      AeMdw.Db.Model.Tx,
      AeMdw.Db.Model.Block,
      AeMdw.Db.Model.Aex9Balance,
      AeMdw.Db.Model.Migrations
    ]
  end

  @spec tables() :: list(atom())
  def tables(),
    do:
      Enum.concat([
        chain_tables(),
        name_tables(),
        contract_tables(),
        oracle_tables(),
        stat_tables(),
        tasks_tables()
      ])

  defp chain_tables() do
    [
      AeMdw.Db.Model.Tx,
      AeMdw.Db.Model.Block,
      AeMdw.Db.Model.Time,
      AeMdw.Db.Model.Type,
      AeMdw.Db.Model.Field,
      AeMdw.Db.Model.IdCount,
      AeMdw.Db.Model.Origin,
      AeMdw.Db.Model.RevOrigin,
      AeMdw.Db.Model.IntTransferTx,
      AeMdw.Db.Model.KindIntTransferTx,
      AeMdw.Db.Model.TargetKindIntTransferTx
    ]
  end

  defp contract_tables() do
    [
      AeMdw.Db.Model.Aex9Contract,
      AeMdw.Db.Model.Aex9ContractSymbol,
      AeMdw.Db.Model.RevAex9Contract,
      AeMdw.Db.Model.Aex9ContractPubkey,
      AeMdw.Db.Model.Aex9Transfer,
      AeMdw.Db.Model.RevAex9Transfer,
      AeMdw.Db.Model.Aex9PairTransfer,
      AeMdw.Db.Model.IdxAex9Transfer,
      AeMdw.Db.Model.Aex9AccountPresence,
      AeMdw.Db.Model.IdxAex9AccountPresence,
      AeMdw.Db.Model.ContractCall,
      AeMdw.Db.Model.ContractLog,
      AeMdw.Db.Model.DataContractLog,
      AeMdw.Db.Model.EvtContractLog,
      AeMdw.Db.Model.IdxContractLog,
      AeMdw.Db.Model.IntContractCall,
      AeMdw.Db.Model.GrpIntContractCall,
      AeMdw.Db.Model.FnameIntContractCall,
      AeMdw.Db.Model.FnameGrpIntContractCall,
      AeMdw.Db.Model.IdIntContractCall,
      AeMdw.Db.Model.GrpIdIntContractCall,
      AeMdw.Db.Model.IdFnameIntContractCall,
      AeMdw.Db.Model.GrpIdFnameIntContractCall
    ]
  end

  defp name_tables() do
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
      AeMdw.Db.Model.ActiveNameOwner,
      AeMdw.Db.Model.InactiveNameOwner
    ]
  end

  defp oracle_tables() do
    [
      AeMdw.Db.Model.ActiveOracleExpiration,
      AeMdw.Db.Model.InactiveOracleExpiration,
      AeMdw.Db.Model.ActiveOracle,
      AeMdw.Db.Model.InactiveOracle
    ]
  end

  defp stat_tables() do
    [
      AeMdw.Db.Model.DeltaStat,
      AeMdw.Db.Model.TotalStat
    ]
  end

  defp tasks_tables() do
    [
      AeMdw.Db.Model.AsyncTasks,
      AeMdw.Db.Model.Migrations
    ]
  end

  @spec records() :: list(atom())
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
      :aex9_balance,
      :aex9_contract,
      :aex9_contract_symbol,
      :rev_aex9_contract,
      :aex9_contract_pubkey,
      :aex9_transfer,
      :rev_aex9_transfer,
      :aex9_pair_transfer,
      :idx_aex9_transfer,
      :aex9_account_presence,
      :idx_aex9_account_presence,
      :contract_call,
      :contract_log,
      :data_contract_log,
      :evt_contract_log,
      :idx_contract_log,
      :int_contract_call,
      :grp_int_contract_call,
      :fname_int_contract_call,
      :fname_grp_int_contract_call,
      :id_int_contract_call,
      :grp_id_int_contract_call,
      :id_fname_int_contract_call,
      :grp_id_fname_int_contract_call,
      :plain_name,
      :auction_bid,
      :expiration,
      :name,
      :owner,
      :pointee,
      :oracle,
      :int_transfer_tx,
      :kind_int_transfer_tx,
      :target_kind_int_transfer_tx,
      :delta_stat,
      :total_stat,
      :migrations,
      :async_tasks
    ]

  @spec fields(atom()) :: list(atom())
  def fields(record),
    do: for({x, _} <- defaults(record), do: x)

  @spec record(atom()) :: atom()
  def record(AeMdw.Db.Model.AsyncTasks), do: :async_tasks
  def record(AeMdw.Db.Model.Migrations), do: :migrations
  def record(AeMdw.Db.Model.Tx), do: :tx
  def record(AeMdw.Db.Model.Block), do: :block
  def record(AeMdw.Db.Model.Time), do: :time
  def record(AeMdw.Db.Model.Type), do: :type
  def record(AeMdw.Db.Model.Field), do: :field
  def record(AeMdw.Db.Model.IdCount), do: :id_count
  def record(AeMdw.Db.Model.Origin), do: :origin
  def record(AeMdw.Db.Model.RevOrigin), do: :rev_origin
  def record(AeMdw.Db.Model.Aex9Balance), do: :aex9_balance
  def record(AeMdw.Db.Model.Aex9Contract), do: :aex9_contract
  def record(AeMdw.Db.Model.Aex9ContractSymbol), do: :aex9_contract_symbol
  def record(AeMdw.Db.Model.RevAex9Contract), do: :rev_aex9_contract
  def record(AeMdw.Db.Model.Aex9ContractPubkey), do: :aex9_contract_pubkey
  def record(AeMdw.Db.Model.Aex9Transfer), do: :aex9_transfer
  def record(AeMdw.Db.Model.RevAex9Transfer), do: :rev_aex9_transfer
  def record(AeMdw.Db.Model.Aex9PairTransfer), do: :aex9_pair_transfer
  def record(AeMdw.Db.Model.IdxAex9Transfer), do: :idx_aex9_transfer
  def record(AeMdw.Db.Model.Aex9AccountPresence), do: :aex9_account_presence
  def record(AeMdw.Db.Model.IdxAex9AccountPresence), do: :idx_aex9_account_presence
  def record(AeMdw.Db.Model.ContractCall), do: :contract_call
  def record(AeMdw.Db.Model.ContractLog), do: :contract_log
  def record(AeMdw.Db.Model.DataContractLog), do: :data_contract_log
  def record(AeMdw.Db.Model.EvtContractLog), do: :evt_contract_log
  def record(AeMdw.Db.Model.IdxContractLog), do: :idx_contract_log
  def record(AeMdw.Db.Model.IntContractCall), do: :int_contract_call
  def record(AeMdw.Db.Model.GrpIntContractCall), do: :grp_int_contract_call
  def record(AeMdw.Db.Model.FnameIntContractCall), do: :fname_int_contract_call
  def record(AeMdw.Db.Model.FnameGrpIntContractCall), do: :fname_grp_int_contract_call
  def record(AeMdw.Db.Model.IdIntContractCall), do: :id_int_contract_call
  def record(AeMdw.Db.Model.GrpIdIntContractCall), do: :grp_id_int_contract_call
  def record(AeMdw.Db.Model.IdFnameIntContractCall), do: :id_fname_int_contract_call
  def record(AeMdw.Db.Model.GrpIdFnameIntContractCall), do: :grp_id_fname_int_contract_call
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
  def record(AeMdw.Db.Model.InactiveNameOwner), do: :owner
  def record(AeMdw.Db.Model.ActiveOracleExpiration), do: :expiration
  def record(AeMdw.Db.Model.InactiveOracleExpiration), do: :expiration
  def record(AeMdw.Db.Model.ActiveOracle), do: :oracle
  def record(AeMdw.Db.Model.InactiveOracle), do: :oracle
  def record(AeMdw.Db.Model.IntTransferTx), do: :int_transfer_tx
  def record(AeMdw.Db.Model.KindIntTransferTx), do: :kind_int_transfer_tx
  def record(AeMdw.Db.Model.TargetKindIntTransferTx), do: :target_kind_int_transfer_tx

  def record(AeMdw.Db.Model.DeltaStat), do: :delta_stat
  def record(AeMdw.Db.Model.TotalStat), do: :total_stat

  @spec table(atom()) :: atom()
  def table(:async_tasks), do: AeMdw.Db.Model.AsyncTasks
  def table(:migrations), do: AeMdw.Db.Model.Migrations
  def table(:tx), do: AeMdw.Db.Model.Tx
  def table(:block), do: AeMdw.Db.Model.Block
  def table(:time), do: AeMdw.Db.Model.Time
  def table(:type), do: AeMdw.Db.Model.Type
  def table(:field), do: AeMdw.Db.Model.Field
  def table(:id_count), do: AeMdw.Db.Model.IdCount
  def table(:origin), do: AeMdw.Db.Model.Origin
  def table(:rev_origin), do: AeMdw.Db.Model.RevOrigin
  def table(:aex9_balance), do: AeMdw.Db.Model.Aex9Balance
  def table(:aex9_contract), do: AeMdw.Db.Model.Aex9Contract
  def table(:aex9_contract_symbol), do: AeMdw.Db.Model.Aex9ContractSymbol
  def table(:rev_aex9_contract), do: AeMdw.Db.Model.RevAex9Contract
  def table(:aex9_contract_pubkey), do: AeMdw.Db.Model.Aex9ContractPubkey
  def table(:aex9_transfer), do: AeMdw.Db.Model.Aex9Transfer
  def table(:rev_aex9_transfer), do: AeMdw.Db.Model.RevAex9Transfer
  def table(:aex9_pair_transfer), do: AeMdw.Db.Model.Aex9PairTransfer
  def table(:idx_aex9_transfer), do: AeMdw.Db.Model.IdxAex9Transfer
  def table(:aex9_account_presence), do: AeMdw.Db.Model.Aex9AccountPresence
  def table(:idx_aex9_account_presence), do: AeMdw.Db.Model.IdxAex9AccountPresence
  def table(:contract_call), do: AeMdw.Db.Model.ContractCall
  def table(:contract_log), do: AeMdw.Db.Model.ContractLog
  def table(:data_contract_log), do: AeMdw.Db.Model.DataContractLog
  def table(:evt_contract_log), do: AeMdw.Db.Model.EvtContractLog
  def table(:idx_contract_log), do: AeMdw.Db.Model.IdxContractLog
  def table(:int_contract_call), do: AeMdw.Db.Model.IntContractCall
  def table(:grp_int_contract_call), do: AeMdw.Db.Model.GrpIntContractCall
  def table(:fname_int_contract_call), do: AeMdw.Db.Model.FnameIntContractCall
  def table(:fname_grp_int_contract_call), do: AeMdw.Db.Model.FnameGrpIntContractCall
  def table(:id_int_contract_call), do: AeMdw.Db.Model.IdIntContractCall
  def table(:grp_id_int_contract_call), do: AeMdw.Db.Model.GrpIdIntContractCall
  def table(:id_fname_int_contract_call), do: AeMdw.Db.Model.IdFnameIntContractCall
  def table(:grp_id_fname_int_contract_call), do: AeMdw.Db.Model.GrpIdFnameIntContractCall
  def table(:int_transfer_tx), do: AeMdw.Db.Model.IntTransferTx
  def table(:kind_int_transfer_tx), do: AeMdw.Db.Model.KindIntTransferTx
  def table(:target_int_transfer_tx), do: AeMdw.Db.Model.TargetIntTransferTx
  def table(:target_kind_int_transfer_tx), do: AeMdw.Db.Model.TargetKindIntTransferTx
  def table(:delta_stat), do: AeMdw.Db.Model.DeltaStat
  def table(:total_stat), do: AeMdw.Db.Model.TotalStat

  @spec defaults(atom()) :: list()
  def defaults(:async_tasks), do: @async_tasks_defaults
  def defaults(:migrations), do: @migrations_defaults
  def defaults(:tx), do: @tx_defaults
  def defaults(:block), do: @block_defaults
  def defaults(:time), do: @time_defaults
  def defaults(:type), do: @type_defaults
  def defaults(:field), do: @field_defaults
  def defaults(:id_count), do: @id_count_defaults
  def defaults(:origin), do: @origin_defaults
  def defaults(:rev_origin), do: @rev_origin_defaults
  def defaults(:aex9_balance), do: @aex9_balance_defaults
  def defaults(:aex9_contract), do: @aex9_contract_defaults
  def defaults(:aex9_contract_symbol), do: @aex9_contract_symbol_defaults
  def defaults(:rev_aex9_contract), do: @rev_aex9_contract_defaults
  def defaults(:aex9_contract_pubkey), do: @aex9_contract_pubkey_defaults
  def defaults(:aex9_transfer), do: @aex9_transfer_defaults
  def defaults(:rev_aex9_transfer), do: @rev_aex9_transfer_defaults
  def defaults(:aex9_pair_transfer), do: @aex9_pair_transfer_defaults
  def defaults(:idx_aex9_transfer), do: @idx_aex9_transfer_defaults
  def defaults(:aex9_account_presence), do: @aex9_account_presence_defaults
  def defaults(:idx_aex9_account_presence), do: @idx_aex9_account_presence_defaults
  def defaults(:contract_call), do: @contract_call_defaults
  def defaults(:contract_log), do: @contract_log_defaults
  def defaults(:data_contract_log), do: @data_contract_log_defaults
  def defaults(:evt_contract_log), do: @evt_contract_log_defaults
  def defaults(:idx_contract_log), do: @idx_contract_log_defaults
  def defaults(:int_contract_call), do: @int_contract_call_defaults
  def defaults(:grp_int_contract_call), do: @grp_int_contract_call_defaults
  def defaults(:fname_int_contract_call), do: @fname_int_contract_call_defaults
  def defaults(:fname_grp_int_contract_call), do: @fname_grp_int_contract_call_defaults
  def defaults(:id_int_contract_call), do: @id_int_contract_call_defaults
  def defaults(:grp_id_int_contract_call), do: @grp_id_int_contract_call_defaults
  def defaults(:id_fname_int_contract_call), do: @id_fname_int_contract_call_defaults
  def defaults(:grp_id_fname_int_contract_call), do: @grp_id_fname_int_contract_call_defaults
  def defaults(:plain_name), do: @plain_name_defaults
  def defaults(:auction_bid), do: @auction_bid_defaults
  def defaults(:pointee), do: @pointee_defaults
  def defaults(:expiration), do: @expiration_defaults
  def defaults(:name), do: @name_defaults
  def defaults(:owner), do: @owner_defaults
  def defaults(:oracle), do: @oracle_defaults
  def defaults(:int_transfer_tx), do: @int_transfer_tx_defaults
  def defaults(:kind_int_transfer_tx), do: @kind_int_transfer_tx_defaults
  def defaults(:target_kind_int_transfer_tx), do: @target_kind_int_transfer_tx_defaults
  def defaults(:delta_stat), do: @delta_stat_defaults
  def defaults(:total_stat), do: @total_stat_defaults

  @spec write_count(tuple(), integer()) :: :ok
  def write_count(model, delta) do
    total = id_count(model, :count)
    model = id_count(model, count: total + delta)
    Database.write(AeMdw.Db.Model.IdCount, model)
  end

  @spec update_count(tuple(), integer(), fun()) :: any()
  def update_count({_, _, _} = field_key, delta, empty_fn \\ fn -> :nop end) do
    case Database.read(AeMdw.Db.Model.IdCount, field_key, :write) do
      [] -> empty_fn.()
      [model] -> write_count(model, delta)
    end
  end

  @spec incr_count(tuple()) :: any()
  def incr_count({_, _, _} = field_key),
    do: update_count(field_key, 1, fn -> write_count(id_count(index: field_key, count: 0), 1) end)
end

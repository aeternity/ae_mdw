defmodule AeMdw.Db.Model do
  @moduledoc """
  Database database model records.
  """
  alias AeMdw.Blocks
  alias AeMdw.Contract
  alias AeMdw.Names
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  require Record
  require Ex2ms

  import Record, only: [defrecord: 2]

  @type table :: atom()
  @type m_record :: tuple()
  @opaque key :: tuple() | integer() | pubkey()

  @typep pubkey :: Db.pubkey()

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
  #     On keyblock boundary: mb_index = -1}
  @block_defaults [index: {-1, -1}, tx_index: nil, hash: <<>>]
  defrecord :block, @block_defaults

  @type block ::
          record(:block,
            index: Blocks.block_index(),
            tx_index: Txs.txi(),
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

  @type id_count_key :: {atom(), non_neg_integer(), pubkey()}
  @type id_count :: record(:id_count, index: id_count_key(), count: non_neg_integer())

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

  @type plain_name ::
          record(:plain_name, index: Names.name_hash(), value: Names.plain_name())

  # auction bid:
  #     index = {plain_name, {block_index, txi}, expire_height = height, owner = pk, prev_bids = []}
  @auction_bid_defaults [
    index: nil,
    block_index_txi: nil,
    expire_height: nil,
    owner: nil,
    bids: []
  ]
  defrecord :auction_bid, @auction_bid_defaults

  @type auction_bid ::
          record(:auction_bid,
            index: Names.plain_name(),
            block_index_txi: Blocks.block_index_txi(),
            expire_height: Blocks.height(),
            owner: pubkey(),
            bids: [Blocks.block_index_txi()]
          )

  # in 3 tables: auction_expiration, name_expiration, inactive_name_expiration
  #
  # expiration:
  #     index = {expire_height, plain_name | oracle_pk}, value: any
  @expiration_defaults [index: {nil, nil}, value: nil]
  defrecord :expiration, @expiration_defaults

  @type expiration ::
          record(:expiration, index: {pos_integer(), String.t() | pubkey()}, value: nil)

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

  @type name ::
          record(:name,
            index: String.t(),
            active: Blocks.height(),
            expire: Blocks.height(),
            claims: list(),
            updates: list(),
            transfers: list(),
            revoke: {Blocks.block_index(), Txs.txi()} | nil,
            auction_timeout: non_neg_integer(),
            owner: pubkey(),
            previous: record(:name) | nil
          )

  # owner: (updated via name claim/transfer)
  #     index = {pubkey, entity},
  @owner_defaults [index: nil, unused: nil]
  defrecord :owner, @owner_defaults

  @type owner() ::
          record(:owner,
            index: {Db.pubkey(), Names.plain_name()},
            unused: nil
          )

  # pointee : (updated when name_update_tx changes pointers)
  #     index = {pointer_val, {block_index, txi}, pointer_key}
  @pointee_defaults [index: {nil, {{nil, nil}, nil}, nil}, unused: nil]
  defrecord :pointee, @pointee_defaults

  @type pointee() ::
          record(:pointee,
            index: {Db.pubkey(), {Blocks.block_index(), Txs.txi()}, Db.pubkey()},
            unused: nil
          )

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
  #     index: {contract_pk, account_pk}
  #     block_index: {kbi, mbi},
  #     txi: call txi,
  #     amount: float
  @type aex9_balance ::
          record(:aex9_balance,
            index: {Db.pubkey(), Db.pubkey()},
            block_index: {Blocks.height(), Blocks.mbi()},
            txi: Txs.txi(),
            amount: float()
          )
  @aex9_balance_defaults [index: {<<>>, <<>>}, block_index: {-1, -1}, txi: nil, amount: nil]
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

  # AEX-N contract:
  #     index: {type, pubkey} where type = :aex9, :aex141, ...
  #     txi: txi
  #     meta_info: {name, symbol, decimals} | {name, symbol, base_url, metadata_type}
  @type aexn_meta_info ::
          {String.t(), String.t(), non_neg_integer()}
          | {String.t(), String.t(), String.t(), atom()}
  @type aexn_contract ::
          record(:aexn_contract,
            index: {:aex9 | :aex141, Db.pubkey()},
            txi: Txs.txi(),
            meta_info: aexn_meta_info()
          )
  @aexn_contract_defaults [
    index: nil,
    txi: -1,
    meta_info: nil
  ]
  defrecord :aexn_contract, @aexn_contract_defaults

  # AEX-N meta info sorted by name:
  #     index: {type, name, pubkey}
  #     unused: nil
  @aexn_contract_name_defaults [
    index: {nil, nil, nil},
    unused: nil
  ]
  defrecord :aexn_contract_name, @aexn_contract_name_defaults

  # AEX-N meta info sorted by symbol:
  #     index: {type, symbol, pubkey}
  #     unused: nil
  @aexn_contract_symbol_defaults [
    index: {nil, nil, nil},
    unused: nil
  ]
  defrecord :aexn_contract_symbol, @aexn_contract_symbol_defaults

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
    Enum.concat([
      chain_tables(),
      contract_tables(),
      name_tables(),
      oracle_tables(),
      stat_tables(),
      tasks_tables()
    ])
  end

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
      AeMdw.Db.Model.Aex9Balance,
      AeMdw.Db.Model.Aex9Contract,
      AeMdw.Db.Model.Aex9ContractSymbol,
      AeMdw.Db.Model.RevAex9Contract,
      AeMdw.Db.Model.Aex9ContractPubkey,
      AeMdw.Db.Model.AexnContract,
      AeMdw.Db.Model.AexnContractName,
      AeMdw.Db.Model.AexnContractSymbol,
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
  def record(AeMdw.Db.Model.AexnContract), do: :aexn_contract
  def record(AeMdw.Db.Model.AexnContractName), do: :aexn_contract_name
  def record(AeMdw.Db.Model.AexnContractSymbol), do: :aexn_contract_symbol
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
end

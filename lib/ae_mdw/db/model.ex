defmodule AeMdw.Db.Model do
  @moduledoc """
  Database database model records.
  """
  alias AeMdw.Blocks
  alias AeMdw.Contract
  alias AeMdw.Names
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Oracles
  alias AeMdw.Txs

  require Record
  require Ex2ms

  import Record, only: [defrecord: 2]

  @type table :: atom()
  @type m_record :: tuple()
  @opaque key :: tuple() | integer() | pubkey()

  @typep height() :: Blocks.height()
  @typep pubkey :: Db.pubkey()
  @typep tx_type() :: Node.tx_type()
  @typep txi() :: Txs.txi()
  @typep log_idx() :: AeMdw.Contracts.log_idx()
  @typep tx_hash() :: Txs.tx_hash()
  @typep bi_txi() :: Blocks.block_index_txi()
  @typep query_id() :: Oracles.query_id()

  ################################################################################

  # index is timestamp (daylight saving order should be handle case by case)
  @typep timestamp :: pos_integer()
  @type async_task_type :: :update_aex9_state
  @type async_task_index :: {timestamp(), async_task_type()}
  @type async_task_args :: list()

  @type async_task_record ::
          record(:async_task,
            index: async_task_index(),
            args: async_task_args(),
            extra_args: async_task_args()
          )
  @async_task_defaults [index: {-1, nil}, args: nil, extra_args: nil]
  defrecord :async_task, @async_task_defaults

  @type async_tasks_record ::
          record(:async_tasks, index: {integer(), atom()}, args: list())
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
            tx_index: txi(),
            hash: Blocks.block_hash()
          )

  # txs table :
  #     index = tx_index (0..), id = tx_id, block_index = {kbi, mbi}
  @tx_defaults [index: -1, id: <<>>, block_index: {-1, -1}, time: -1]
  defrecord :tx, @tx_defaults

  @type tx ::
          record(:tx,
            index: txi(),
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

  @type type() :: record(:type, index: {tx_type(), txi()})

  # txs type count index  :
  #     index = tx_type
  @type_count_defaults [index: nil, count: 0]
  defrecord :type_count, @type_count_defaults

  @type type_count() :: record(:type_count, index: tx_type(), count: non_neg_integer())

  # txs fields      :
  #     index = {tx_type, tx_field_pos, object_pubkey, tx_index},
  @field_defaults [index: {nil, -1, nil, -1}, unused: nil]
  defrecord :field, @field_defaults

  @type field() :: record(:field, index: {tx_type(), non_neg_integer() | -1, pubkey(), txi()})

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

  @type origin() :: record(:origin, index: {tx_type(), pubkey(), txi()}, tx_id: tx_hash())

  # we need this one to quickly locate origin keys to delete for invalidating a fork
  #
  # rev object origin :
  #     index = {tx_index, tx_type, pubkey}
  @rev_origin_defaults [index: {nil, nil, nil}, unused: nil]
  defrecord :rev_origin, @rev_origin_defaults

  @type rev_origin() :: record(:rev_origin, index: {txi(), tx_type(), pubkey()})

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
            block_index_txi: bi_txi(),
            expire_height: Blocks.height(),
            owner: pubkey(),
            bids: [bi_txi()]
          )

  # activation:
  #     index = {height, plain_name}, value: any
  @activation_defaults [index: {nil, nil}, value: nil]
  defrecord :activation, @activation_defaults

  @type activation ::
          record(:activation, index: {Blocks.height(), String.t()}, value: nil)

  # in 3 tables: auction_expiration, name_expiration, inactive_name_expiration
  #
  # expiration:
  #     index = {expire_height, plain_name | oracle_pk}
  @expiration_defaults [index: {nil, nil}, unused: nil]
  defrecord :expiration, @expiration_defaults

  @type expiration ::
          record(:expiration, index: {Blocks.height(), String.t() | pubkey()})

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
            claims: [bi_txi()],
            updates: [bi_txi()],
            transfers: [bi_txi()],
            revoke: bi_txi() | nil,
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
            index: {pubkey(), Names.plain_name()},
            unused: nil
          )

  # owner_deactivation:
  #     index = {owner_pk, deactivate_height, plain_name},
  @owner_deactivation_defaults [index: nil, unused: nil]
  defrecord :owner_deactivation, @owner_deactivation_defaults

  @type owner_deactivation() ::
          record(:owner_deactivation,
            index: {pubkey(), height(), Names.plain_name()},
            unused: nil
          )

  # pointee : (updated when name_update_tx changes pointers)
  #     index = {pointer_val, {block_index, txi}, pointer_key}
  @pointee_defaults [index: {nil, {{nil, nil}, nil}, nil}, unused: nil]
  defrecord :pointee, @pointee_defaults

  @type pointee() ::
          record(:pointee,
            index: {pubkey(), bi_txi(), pubkey()},
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
            index: pubkey(),
            active: Blocks.height(),
            expire: Blocks.height(),
            register: bi_txi(),
            extends: [bi_txi()],
            previous: oracle() | nil
          )

  # oracle_query
  #   index = {oracle_pk, query_id}
  @oracle_query_defaults [
    index: nil,
    txi: nil,
    sender_pk: nil,
    fee: nil,
    expire: nil
  ]
  defrecord :oracle_query, @oracle_query_defaults

  @type oracle_query() ::
          record(:oracle_query,
            index: {pubkey(), query_id()},
            txi: txi(),
            sender_pk: pubkey(),
            fee: non_neg_integer(),
            expire: height()
          )

  # oracle_query_expiration
  #   index = {expiration_height, oracle_pk, query_id}
  @oracle_query_expiration_defaults [
    index: nil,
    unused: nil
  ]
  defrecord :oracle_query_expiration, @oracle_query_expiration_defaults

  @type oracle_query_expiration() ::
          record(:oracle_query_expiration, index: {height(), pubkey(), query_id()})

  @channel_defaults [
    index: nil,
    active: nil,
    initiator: nil,
    responder: nil,
    state_hash: nil,
    amount: nil,
    updates: nil
  ]
  defrecord :channel, @channel_defaults

  @type channel() ::
          record(:channel,
            index: pubkey(),
            active: height(),
            initiator: pubkey(),
            responder: pubkey(),
            state_hash: binary(),
            amount: non_neg_integer(),
            updates: [bi_txi()]
          )

  # AEX9 event balance:
  #     index: {contract_pk, account_pk}
  #     txi: call txi,
  #     log_idx: event log index,
  #     amount: float
  @type aex9_event_balance ::
          record(:aex9_event_balance,
            index: {pubkey(), pubkey()},
            txi: txi(),
            log_idx: log_idx(),
            amount: float()
          )
  @aex9_event_balance_defaults [
    index: {<<>>, <<>>},
    txi: nil,
    log_idx: -1,
    amount: nil
  ]
  defrecord :aex9_event_balance, @aex9_event_balance_defaults

  # AEX9 balance:
  #     index: {contract_pk, account_pk}
  #     block_index: {kbi, mbi},
  #     txi: call txi,
  #     amount: float
  @type aex9_balance ::
          record(:aex9_balance,
            index: {pubkey(), pubkey()},
            block_index: {Blocks.height(), Blocks.mbi()},
            txi: txi(),
            amount: float()
          )
  @aex9_balance_defaults [index: {<<>>, <<>>}, block_index: {-1, -1}, txi: nil, amount: nil]
  defrecord :aex9_balance, @aex9_balance_defaults

  # AEX-N contract:
  #     index: {type, pubkey} where type = :aex9, :aex141, ...
  #     txi: txi
  #     meta_info: {name, symbol, decimals} | {name, symbol, base_url, metadata_type}
  @type aexn_type :: :aex9 | :aex141
  @type aexn_name :: String.t()
  @type aexn_symbol :: String.t()
  @type aex9_meta_info :: {aexn_name(), aexn_symbol(), non_neg_integer()}
  @type aex141_metadata_type :: :url | :ipfs | :object_id | :map
  @type aex141_meta_info :: {aexn_name(), aexn_symbol(), String.t(), aex141_metadata_type()}
  @type aexn_meta_info :: aex9_meta_info() | aex141_meta_info()
  @type aexn_extensions :: [String.t()]

  @type aexn_contract ::
          record(:aexn_contract,
            index: {aexn_type(), pubkey()},
            txi: txi(),
            meta_info: aexn_meta_info(),
            extensions: aexn_extensions()
          )
  @aexn_contract_defaults [
    index: nil,
    txi: -1,
    meta_info: nil,
    extensions: []
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

  # AEX-141 owner tokens
  #     index: {owner pubkey, contract pubkey, token_id}, template_id: integer()
  @nft_ownership_defaults [index: nil, template_id: nil]
  defrecord :nft_ownership, @nft_ownership_defaults

  @type nft_ownership() ::
          record(:nft_ownership,
            index: {pubkey(), pubkey(), AeMdw.Aex141.token_id()},
            template_id: integer()
          )

  # AEX-141 templates
  #     index: {contract pubkey, template_id}
  #     txi: creation txi
  #     log_idx: creation event
  #     limit: {amount, txi, log_idx} | nil
  @nft_template_defaults [index: {<<>>, -1}, txi: nil, log_idx: nil, limit: nil]
  defrecord :nft_template, @nft_template_defaults

  @type nft_template() ::
          record(:nft_template,
            index: {pubkey(), integer()},
            txi: txi() | nil,
            log_idx: log_idx() | nil,
            limit: {pos_integer(), txi(), log_idx()} | nil
          )

  # AEX-141 collection owners
  #     index: {contract pubkey, owner pubkey, token_id}
  @nft_owner_token_defaults [index: nil, unused: nil]
  defrecord :nft_owner_token, @nft_owner_token_defaults

  @type nft_owner_token() ::
          record(:nft_owner_token,
            index: {pubkey(), pubkey(), AeMdw.Aex141.token_id()},
            unused: nil
          )

  # AEX-141 token owner
  #     index: {contract pubkey, token_id}, owner: pubkey
  @nft_token_owner_defaults [index: {<<>>, -1}, owner: <<>>]
  defrecord :nft_token_owner, @nft_token_owner_defaults

  @type nft_token_owner() ::
          record(:nft_token_owner,
            index: {pubkey(), AeMdw.Aex141.token_id()},
            owner: pubkey()
          )

  # AEX-141 token limit
  #     index: contract pubkey, token_limit: integer, template_limit: integer, txi: integer, log_idx: integer
  @nft_contract_limits_defaults [
    index: <<>>,
    token_limit: nil,
    template_limit: nil,
    txi: nil,
    log_idx: nil
  ]
  defrecord :nft_contract_limits, @nft_contract_limits_defaults

  @type nft_contract_limits() ::
          record(:nft_contract_limits,
            index: pubkey(),
            token_limit: pos_integer() | nil,
            template_limit: pos_integer() | nil,
            txi: txi() | nil,
            log_idx: log_idx() | nil
          )

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
  #     index: {call txi, log idx, create_txi, event hash}
  @idx_contract_log_defaults [
    index: {-1, -1, -1, <<>>},
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

  # aexn transfer:
  #    index: {:aex9 | :aex141, from pk, call txi, to pk, amount | token_id, log idx}
  @aexn_transfer_defaults [
    index: {nil, <<>>, -1, <<>>, -1, -1},
    contract_pk: <<>>
  ]
  defrecord :aexn_transfer, @aexn_transfer_defaults

  # rev aexn transfer:
  #    index: {:aex9 | :aex141, to pk, call txi, from pk, amount | token_id, log idx}
  @rev_aexn_transfer_defaults [
    index: {nil, <<>>, -1, <<>>, -1, -1},
    unused: nil
  ]
  defrecord :rev_aexn_transfer, @rev_aexn_transfer_defaults

  # aexn pair transfer:
  #    index: {:aex9 | :aex141, from pk, to pk, call txi, amount | token_id, log idx}
  @aexn_pair_transfer_defaults [
    index: {nil, <<>>, <<>>, -1, -1, -1},
    unused: nil
  ]
  defrecord :aexn_pair_transfer, @aexn_pair_transfer_defaults

  # aexn contract from transfer:
  #    index: {create_txi, from pk, call txi, to pk, amount | token_id, log idx}
  @aexn_contract_from_transfer_defaults [
    index: {-1, <<>>, <<>>, -1, -1, -1},
    unused: nil
  ]
  defrecord :aexn_contract_from_transfer, @aexn_contract_from_transfer_defaults

  # aexn contract to transfer:
  #    index: {create_txi, to pk, call txi, from pk, amount | token_id, log idx}
  @aexn_contract_to_transfer_defaults [
    index: {-1, <<>>, <<>>, -1, -1, -1},
    unused: nil
  ]
  defrecord :aexn_contract_to_transfer, @aexn_contract_to_transfer_defaults

  # aex9 account presence:
  #    index: {account pk, contract pk}
  #    txi: create or call txi
  @aex9_account_presence_defaults [
    index: {nil, nil},
    txi: -1
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

  # int_transfer_tx:
  #   index: {{height, -1 (generation related transfer OR >=0 txi (tx related transfer)}, kind, target, ref txi}
  @int_transfer_tx_defaults [
    index: {{-1, -1}, nil, <<>>, -1},
    amount: 0
  ]
  defrecord :int_transfer_tx, @int_transfer_tx_defaults

  # kind_int_transfer_tx:
  #  index: {kind, block_index, target, ref txi}
  @kind_int_transfer_tx_defaults [
    index: {nil, {-1, -1}, <<>>, -1},
    unused: nil
  ]
  defrecord :kind_int_transfer_tx, @kind_int_transfer_tx_defaults

  # target_kind_int_transfer_tx
  #  index: {target, kind, block_index, ref txi}
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
    dev_reward: 0,
    locked_in_auctions: 0,
    burned_in_auctions: 0,
    channels_opened: 0,
    channels_closed: 0,
    locked_in_channels: 0
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
            dev_reward: integer(),
            locked_in_auctions: integer(),
            burned_in_auctions: integer(),
            channels_opened: non_neg_integer(),
            channels_closed: non_neg_integer(),
            locked_in_channels: integer()
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
    contracts: 0,
    locked_in_auctions: 0,
    burned_in_auctions: 0,
    locked_in_channels: 0,
    open_channels: 0
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
            contracts: integer(),
            locked_in_auctions: non_neg_integer(),
            burned_in_auctions: non_neg_integer(),
            locked_in_channels: non_neg_integer(),
            open_channels: non_neg_integer()
          )

  @stat_defaults [:index, :payload]
  defrecord :stat, @stat_defaults

  @type stat() :: record(:stat, index: atom() | {atom(), pubkey()}, payload: term())

  @miner_defaults [:index, :total_reward]
  defrecord :miner, @miner_defaults

  @type miner() :: record(:miner, index: pubkey(), total_reward: non_neg_integer())

  ################################################################################

  # starts with only chain_tables and add them progressively by groups
  @spec column_families() :: list(atom())
  def column_families do
    Enum.concat([
      chain_tables(),
      contract_tables(),
      channel_tables(),
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
      AeMdw.Db.Model.TypeCount,
      AeMdw.Db.Model.Field,
      AeMdw.Db.Model.IdCount,
      AeMdw.Db.Model.Origin,
      AeMdw.Db.Model.RevOrigin,
      AeMdw.Db.Model.IntTransferTx,
      AeMdw.Db.Model.KindIntTransferTx,
      AeMdw.Db.Model.TargetKindIntTransferTx,
      AeMdw.Db.Model.Miner
    ]
  end

  defp channel_tables() do
    [
      AeMdw.Db.Model.ActiveChannel,
      AeMdw.Db.Model.ActiveChannelActivation,
      AeMdw.Db.Model.InactiveChannel
    ]
  end

  defp contract_tables() do
    [
      AeMdw.Db.Model.Aex9Balance,
      AeMdw.Db.Model.Aex9EventBalance,
      AeMdw.Db.Model.AexnContract,
      AeMdw.Db.Model.AexnContractName,
      AeMdw.Db.Model.AexnContractSymbol,
      AeMdw.Db.Model.AexnTransfer,
      AeMdw.Db.Model.RevAexnTransfer,
      AeMdw.Db.Model.AexnPairTransfer,
      AeMdw.Db.Model.AexnContractFromTransfer,
      AeMdw.Db.Model.AexnContractToTransfer,
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
      AeMdw.Db.Model.GrpIdFnameIntContractCall,
      AeMdw.Db.Model.NftOwnership,
      AeMdw.Db.Model.NftOwnerToken,
      AeMdw.Db.Model.NftTokenOwner,
      AeMdw.Db.Model.NftContractLimits,
      AeMdw.Db.Model.NftTemplate
    ]
  end

  defp name_tables() do
    [
      AeMdw.Db.Model.PlainName,
      AeMdw.Db.Model.AuctionBid,
      AeMdw.Db.Model.Pointee,
      AeMdw.Db.Model.AuctionExpiration,
      AeMdw.Db.Model.ActiveNameActivation,
      AeMdw.Db.Model.ActiveNameExpiration,
      AeMdw.Db.Model.InactiveNameExpiration,
      AeMdw.Db.Model.ActiveName,
      AeMdw.Db.Model.InactiveName,
      AeMdw.Db.Model.AuctionOwner,
      AeMdw.Db.Model.ActiveNameOwner,
      AeMdw.Db.Model.ActiveNameOwnerDeactivation,
      AeMdw.Db.Model.InactiveNameOwnerDeactivation,
      AeMdw.Db.Model.InactiveNameOwner
    ]
  end

  defp oracle_tables() do
    [
      AeMdw.Db.Model.ActiveOracleExpiration,
      AeMdw.Db.Model.InactiveOracleExpiration,
      AeMdw.Db.Model.ActiveOracle,
      AeMdw.Db.Model.InactiveOracle,
      AeMdw.Db.Model.OracleQuery,
      AeMdw.Db.Model.OracleQueryExpiration
    ]
  end

  defp stat_tables() do
    [
      AeMdw.Db.Model.DeltaStat,
      AeMdw.Db.Model.TotalStat,
      AeMdw.Db.Model.Stat
    ]
  end

  defp tasks_tables() do
    [
      AeMdw.Db.Model.AsyncTask,
      AeMdw.Db.Model.AsyncTasks,
      AeMdw.Db.Model.Migrations
    ]
  end

  @spec record(atom()) :: atom()
  def record(AeMdw.Db.Model.AsyncTask), do: :async_task
  def record(AeMdw.Db.Model.AsyncTasks), do: :async_tasks
  def record(AeMdw.Db.Model.Migrations), do: :migrations
  def record(AeMdw.Db.Model.Tx), do: :tx
  def record(AeMdw.Db.Model.Block), do: :block
  def record(AeMdw.Db.Model.Time), do: :time
  def record(AeMdw.Db.Model.Type), do: :type
  def record(AeMdw.Db.Model.TypeCount), do: :type_count
  def record(AeMdw.Db.Model.Field), do: :field
  def record(AeMdw.Db.Model.IdCount), do: :id_count
  def record(AeMdw.Db.Model.Origin), do: :origin
  def record(AeMdw.Db.Model.RevOrigin), do: :rev_origin
  def record(AeMdw.Db.Model.Aex9Balance), do: :aex9_balance
  def record(AeMdw.Db.Model.Aex9EventBalance), do: :aex9_event_balance
  def record(AeMdw.Db.Model.AexnContract), do: :aexn_contract
  def record(AeMdw.Db.Model.AexnContractName), do: :aexn_contract_name
  def record(AeMdw.Db.Model.AexnContractSymbol), do: :aexn_contract_symbol
  def record(AeMdw.Db.Model.AexnTransfer), do: :aexn_transfer
  def record(AeMdw.Db.Model.RevAexnTransfer), do: :rev_aexn_transfer
  def record(AeMdw.Db.Model.AexnPairTransfer), do: :aexn_pair_transfer
  def record(AeMdw.Db.Model.AexnContractFromTransfer), do: :aexn_contract_from_transfer
  def record(AeMdw.Db.Model.AexnContractToTransfer), do: :aexn_contract_to_transfer
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
  def record(AeMdw.Db.Model.NftOwnership), do: :nft_ownership
  def record(AeMdw.Db.Model.NftOwnerToken), do: :nft_owner_token
  def record(AeMdw.Db.Model.NftTokenOwner), do: :nft_token_owner
  def record(AeMdw.Db.Model.NftContractLimits), do: :nft_contract_limits
  def record(AeMdw.Db.Model.NftTemplate), do: :nft_template
  def record(AeMdw.Db.Model.PlainName), do: :plain_name
  def record(AeMdw.Db.Model.AuctionBid), do: :auction_bid
  def record(AeMdw.Db.Model.Pointee), do: :pointee
  def record(AeMdw.Db.Model.AuctionExpiration), do: :expiration
  def record(AeMdw.Db.Model.ActiveNameActivation), do: :activation
  def record(AeMdw.Db.Model.ActiveNameExpiration), do: :expiration
  def record(AeMdw.Db.Model.InactiveNameExpiration), do: :expiration
  def record(AeMdw.Db.Model.ActiveName), do: :name
  def record(AeMdw.Db.Model.InactiveName), do: :name
  def record(AeMdw.Db.Model.AuctionOwner), do: :owner
  def record(AeMdw.Db.Model.ActiveNameOwner), do: :owner
  def record(AeMdw.Db.Model.InactiveNameOwner), do: :owner
  def record(AeMdw.Db.Model.ActiveNameOwnerDeactivation), do: :owner_deactivation
  def record(AeMdw.Db.Model.InactiveNameOwnerDeactivation), do: :owner_deactivation
  def record(AeMdw.Db.Model.ActiveOracleExpiration), do: :expiration
  def record(AeMdw.Db.Model.InactiveOracleExpiration), do: :expiration
  def record(AeMdw.Db.Model.ActiveOracle), do: :oracle
  def record(AeMdw.Db.Model.InactiveOracle), do: :oracle
  def record(AeMdw.Db.Model.OracleQuery), do: :oracle_query
  def record(AeMdw.Db.Model.OracleQueryExpiration), do: :oracle_query_expiration
  def record(AeMdw.Db.Model.ActiveChannel), do: :channel
  def record(AeMdw.Db.Model.ActiveChannelActivation), do: :activation
  def record(AeMdw.Db.Model.InactiveChannel), do: :channel
  def record(AeMdw.Db.Model.IntTransferTx), do: :int_transfer_tx
  def record(AeMdw.Db.Model.KindIntTransferTx), do: :kind_int_transfer_tx
  def record(AeMdw.Db.Model.TargetKindIntTransferTx), do: :target_kind_int_transfer_tx
  def record(AeMdw.Db.Model.DeltaStat), do: :delta_stat
  def record(AeMdw.Db.Model.TotalStat), do: :total_stat
  def record(AeMdw.Db.Model.Stat), do: :stat
  def record(AeMdw.Db.Model.Miner), do: :miner
end

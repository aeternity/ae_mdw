defmodule AeMdw.Db.Model do
  @moduledoc """
  Database database model records.
  """
  alias AeMdw.Blocks
  alias AeMdw.Contract
  alias AeMdw.Contracts
  alias AeMdw.Db.Contract, as: DbContract
  alias AeMdw.Db.IntTransfer
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
  @type aexn_type :: :aex9 | :aex141
  @type aexn_name :: String.t()
  @type aexn_symbol :: String.t()
  @type aex9_meta_info :: {aexn_name(), aexn_symbol(), non_neg_integer()}
  @type aex141_metadata_type :: :url | :ipfs | :object_id | :map
  @type aex141_meta_info :: {aexn_name(), aexn_symbol(), String.t(), aex141_metadata_type()}
  @type aexn_meta_info :: aex9_meta_info() | aex141_meta_info()
  @type aexn_extensions :: [String.t()]
  @type block_index :: Blocks.block_index()

  @typep height() :: Blocks.height()
  @typep pubkey :: Db.pubkey()
  @typep tx_type() :: Node.tx_type()
  @typep txi() :: Txs.txi()
  @typep txi_idx() :: Txs.txi_idx()
  @typep log_idx() :: Contracts.log_idx()
  @typep tx_hash() :: Txs.tx_hash()
  @typep bi_txi() :: Blocks.bi_txi()
  @typep bi_txi_idx() :: Blocks.bi_txi_idx()
  @typep query_id() :: Oracles.query_id()
  @typep amount() :: non_neg_integer()
  @typep fname() :: Contract.fname()

  @typep token_id :: AeMdw.Aex141.token_id()
  @typep template_id :: AeMdw.Aex141.template_id()

  ################################################################################

  # index is timestamp (daylight saving order should be handle case by case)
  @typep timestamp :: pos_integer()
  @type async_task_type :: :update_aex9_state | :store_acc_balance
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

  @type async_task() ::
          record(:async_task,
            index: async_task_index(),
            args: async_task_args(),
            extra_args: async_task_args()
          )

  @async_tasks_defaults [index: {-1, nil}, args: nil]
  defrecord :async_tasks, @async_tasks_defaults

  @type async_tasks_index() :: async_task_index()
  @type async_tasks() :: record(:async_task, index: async_task_index(), args: async_task_args())

  # index is version like 20210826171900 in 20210826171900_reindex_remote_logs.ex
  @migrations_defaults [index: -1, inserted_at: nil]
  defrecord :migrations, @migrations_defaults

  @type migrations_index() :: non_neg_integer()
  @type migrations() ::
          record(:migrations, index: migrations_index(), inserted_at: non_neg_integer())

  @balance_account_defaults [index: nil]
  defrecord :balance_account, @balance_account_defaults

  @type balance_account_index() :: {non_neg_integer(), pubkey()}
  @type balance_account() ::
          record(:balance_account,
            index: {amount(), pubkey()}
          )

  # txs block index :
  #     index = {kb_index (0..), mb_index}, tx_index = tx_index, hash = block (header) hash
  #     On keyblock boundary: mb_index = -1}
  @block_defaults [index: {-1, -1}, tx_index: nil, hash: <<>>]
  defrecord :block, @block_defaults

  @type block ::
          record(:block,
            index: block_index(),
            tx_index: txi(),
            hash: Blocks.block_hash()
          )

  # txs table :
  #     index = tx_index (0..), id = tx_id, block_index = {kbi, mbi}
  @tx_defaults [index: -1, id: <<>>, block_index: {-1, -1}, time: -1]
  defrecord :tx, @tx_defaults

  @type tx_index() :: txi()
  @type tx ::
          record(:tx,
            index: tx_index(),
            id: Txs.tx_hash(),
            block_index: Blocks.block_index(),
            time: Blocks.time()
          )

  # txs time index :
  #     index = {mb_time_msecs (0..), tx_index = (0...)},
  @time_defaults [index: {-1, -1}, unused: nil]
  defrecord :time, @time_defaults

  @type time_index() :: {non_neg_integer(), txi()}
  @type time() :: record(:time, index: time_index())

  # txs type index  :
  #     index = {tx_type, tx_index}
  @type_defaults [index: {nil, -1}, unused: nil]
  defrecord :type, @type_defaults

  @type type_index() :: {tx_type(), txi()}
  @type type() :: record(:type, index: type_index())

  # txs type count index  :
  #     index = tx_type
  @type_count_defaults [index: nil, count: 0]
  defrecord :type_count, @type_count_defaults

  @type type_count_index() :: tx_type()
  @type type_count() :: record(:type_count, index: type_count_index(), count: non_neg_integer())

  # txs fields      :
  #     index = {tx_type, tx_field_pos, object_pubkey, tx_index},
  @field_defaults [index: {nil, -1, nil, -1}, unused: nil]
  defrecord :field, @field_defaults

  @type field_index() :: {tx_type(), non_neg_integer() | -1 | nil, pubkey(), txi()}
  @type field() :: record(:field, index: field_index())

  # id counts       :
  #     index = {tx_type, tx_field_pos, object_pubkey}
  @id_count_defaults [index: {nil, nil, nil}, count: 0]
  defrecord :id_count, @id_count_defaults

  @type id_count_index() :: {atom(), non_neg_integer(), pubkey()}
  @type id_count() :: record(:id_count, index: id_count_index(), count: non_neg_integer())

  # object origin :
  #     index = {tx_type, pubkey, tx_index}, tx_id = tx_hash
  @origin_defaults [index: {nil, nil, nil}, tx_id: nil]
  defrecord :origin, @origin_defaults

  @type origin_index() :: {tx_type(), pubkey(), txi()}
  @type origin() :: record(:origin, index: origin_index(), tx_id: tx_hash())

  # we need this one to quickly locate origin keys to delete for invalidating a fork
  #
  # rev object origin :
  #     index = {tx_index, tx_type, pubkey}
  @rev_origin_defaults [index: {nil, nil, nil}, unused: nil]
  defrecord :rev_origin, @rev_origin_defaults

  @type rev_origin_index() :: {txi(), tx_type(), pubkey()}
  @type rev_origin() :: record(:rev_origin, index: rev_origin_index())

  # plain name:
  #     index = name_hash, plain = plain name
  @plain_name_defaults [index: nil, value: nil]
  defrecord :plain_name, @plain_name_defaults

  @type plain_name_index() :: Names.name_hash()
  @type plain_name() ::
          record(:plain_name, index: plain_name_index(), value: Names.plain_name())

  # auction bid:
  #     index = {plain_name, {block_index, txi}, expire_height = height, owner = pk, prev_bids = []}
  @auction_bid_defaults [
    index: nil,
    block_index_txi_idx: nil,
    expire_height: nil,
    owner: nil,
    bids: []
  ]
  defrecord :auction_bid, @auction_bid_defaults

  @type auction_bid_index() :: Names.plain_name()
  @type auction_bid ::
          record(:auction_bid,
            index: auction_bid_index(),
            block_index_txi_idx: bi_txi_idx(),
            expire_height: Blocks.height(),
            owner: pubkey(),
            bids: [bi_txi_idx()]
          )

  # activation:
  #     index = {height, plain_name}, value: any
  @activation_defaults [index: {nil, nil}, value: nil]
  defrecord :activation, @activation_defaults

  @type activation_index() :: {Blocks.height(), String.t()}
  @type activation ::
          record(:activation, index: activation_index(), value: nil)

  # in 3 tables: auction_expiration, name_expiration, inactive_name_expiration
  #
  # expiration:
  #     index = {expire_height, plain_name | oracle_pk}
  @expiration_defaults [index: {nil, nil}, unused: nil]
  defrecord :expiration, @expiration_defaults

  @type expiration_index() :: {Blocks.height(), String.t() | pubkey()}
  @type expiration :: record(:expiration, index: expiration_index())

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

  @type name_index() :: Names.plain_name()
  @type name ::
          record(:name,
            index: name_index(),
            active: Blocks.height(),
            expire: Blocks.height(),
            claims: [bi_txi_idx()],
            updates: [bi_txi_idx()],
            transfers: [bi_txi_idx()],
            revoke: bi_txi_idx() | nil,
            auction_timeout: non_neg_integer(),
            owner: pubkey(),
            previous: record(:name) | nil
          )

  # owner: (updated via name claim/transfer)
  #     index = {pubkey, entity},
  @owner_defaults [index: nil, unused: nil]
  defrecord :owner, @owner_defaults

  @type owner_index() :: {pubkey(), Names.plain_name()}
  @type owner() :: record(:owner, index: owner_index())

  # owner_deactivation:
  #     index = {owner_pk, deactivate_height, plain_name},
  @owner_deactivation_defaults [index: nil, unused: nil]
  defrecord :owner_deactivation, @owner_deactivation_defaults

  @type owner_deactivation_index() :: {pubkey(), height(), Names.plain_name()}
  @type owner_deactivation() :: record(:owner_deactivation, index: owner_deactivation_index())

  # pointee : (updated when name_update_tx changes pointers)
  #     index = {pointer_val, {block_index, txi_idx}, pointer_key}
  @pointee_defaults [index: nil, unused: nil]
  defrecord :pointee, @pointee_defaults

  @type pointee_index() :: {pubkey(), bi_txi_idx(), pubkey()}
  @type pointee() :: record(:pointee, index: pointee_index())

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

  @type oracle_index() :: pubkey()
  @type oracle() ::
          record(:oracle,
            index: oracle_index(),
            active: Blocks.height(),
            expire: Blocks.height(),
            register: bi_txi_idx(),
            extends: [bi_txi_idx()],
            previous: oracle() | nil
          )

  # oracle_query
  #   index = {oracle_pk, query_id}
  @oracle_query_defaults [
    index: nil,
    txi_idx: nil
  ]
  defrecord :oracle_query, @oracle_query_defaults

  @type oracle_query_index() :: {pubkey(), query_id()}
  @type oracle_query() ::
          record(:oracle_query,
            index: oracle_query_index(),
            txi_idx: txi_idx()
          )

  # oracle_query_expiration
  #   index = {expiration_height, oracle_pk, query_id}
  @oracle_query_expiration_defaults [
    index: nil,
    unused: nil
  ]
  defrecord :oracle_query_expiration, @oracle_query_expiration_defaults

  @type oracle_query_expiration_index() :: {height(), pubkey(), query_id()}
  @type oracle_query_expiration() ::
          record(:oracle_query_expiration, index: oracle_query_expiration_index())

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

  @type channel_index() :: pubkey()
  @type channel() ::
          record(:channel,
            index: channel_index(),
            active: height(),
            initiator: pubkey(),
            responder: pubkey(),
            state_hash: binary(),
            amount: non_neg_integer(),
            updates: [bi_txi_idx()]
          )

  # AEX9 event balance:
  #     index: {contract_pk, account_pk}
  #     txi: call txi,
  #     log_idx: event log index,
  #     amount: float
  @type aex9_event_balance_index() :: {pubkey(), pubkey()}
  @type aex9_event_balance ::
          record(:aex9_event_balance,
            index: aex9_event_balance_index(),
            txi: txi(),
            log_idx: log_idx(),
            amount: integer()
          )
  @aex9_event_balance_defaults [
    index: {<<>>, <<>>},
    txi: nil,
    log_idx: -1,
    amount: nil
  ]
  defrecord :aex9_event_balance, @aex9_event_balance_defaults

  # AEX9 initial supply:
  #     index: contract_pk
  #     amount: float
  @type aex9_initial_supply_index() :: pubkey()
  @type aex9_initial_supply ::
          record(:aex9_initial_supply,
            index: aex9_initial_supply_index(),
            amount: integer()
          )
  @aex9_initial_supply_defaults [
    index: {<<>>, <<>>},
    amount: nil
  ]
  defrecord :aex9_initial_supply, @aex9_initial_supply_defaults

  # AEX9 contract balance:
  #     index: contract_pk
  #     amount: float
  @type aex9_contract_balance_index() :: pubkey()
  @type aex9_contract_balance ::
          record(:aex9_contract_balance,
            index: aex9_contract_balance_index(),
            amount: integer()
          )
  @aex9_contract_balance_defaults [
    index: <<>>,
    amount: nil
  ]
  defrecord :aex9_contract_balance, @aex9_contract_balance_defaults

  # AEX9 balance:
  #     index: {contract_pk, account_pk}
  #     block_index: {kbi, mbi},
  #     txi: call txi,
  #     amount: float
  @type aex9_balance_index() :: {pubkey(), pubkey()}
  @type aex9_balance ::
          record(:aex9_balance,
            index: aex9_balance_index(),
            block_index: {Blocks.height(), Blocks.mbi()},
            txi: txi(),
            amount: integer()
          )
  @aex9_balance_defaults [index: {<<>>, <<>>}, block_index: {-1, -1}, txi: nil, amount: nil]
  defrecord :aex9_balance, @aex9_balance_defaults

  # AEX-N contract:
  #     index: {type, pubkey} where type = :aex9, :aex141, ...
  #     txi: txi
  #     meta_info: {name, symbol, decimals} | {name, symbol, base_url, metadata_type}
  @type aexn_contract_index() :: {aexn_type(), pubkey()}
  @type aexn_contract ::
          record(:aexn_contract,
            index: aexn_contract_index(),
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

  @type aexn_contract_name_index() :: {aexn_type(), binary(), pubkey()}
  @type aexn_contract_name() ::
          record(:aexn_contract_name, index: aexn_contract_name_index())

  # AEX-N meta info sorted by symbol:
  #     index: {type, symbol, pubkey}
  #     unused: nil
  @aexn_contract_symbol_defaults [
    index: {nil, nil, nil},
    unused: nil
  ]
  defrecord :aexn_contract_symbol, @aexn_contract_symbol_defaults

  @type aexn_contract_symbol_index() :: {aexn_type(), aexn_symbol(), pubkey()}
  @type aexn_contract_symbol() ::
          record(:aexn_contract_symbol, index: aexn_contract_symbol_index())

  # AEX-141 owner tokens
  #     index: {owner pubkey, contract pubkey, token_id}, template_id: integer()
  @nft_ownership_defaults [index: nil, template_id: nil]
  defrecord :nft_ownership, @nft_ownership_defaults

  @type nft_ownership_index() :: {pubkey(), pubkey(), AeMdw.Aex141.token_id()}
  @type nft_ownership() ::
          record(:nft_ownership,
            index: nft_ownership_index(),
            template_id: template_id()
          )

  # AEX-141 templates
  #     index: {contract pubkey, template_id}
  #     txi: creation txi
  #     log_idx: creation event
  #     limit: {amount, txi, log_idx} | nil
  @nft_template_defaults [index: {<<>>, -1}, txi: nil, log_idx: nil, limit: nil]
  defrecord :nft_template, @nft_template_defaults

  @type nft_template_index() :: {pubkey(), integer()}
  @type nft_template() ::
          record(:nft_template,
            index: nft_template_index(),
            txi: txi(),
            log_idx: log_idx(),
            limit: {pos_integer(), txi(), log_idx()} | nil
          )

  # AEX-141 template token
  #     index: {contract pubkey, template_id, token_id}
  #     txi: mint txi
  #     log_idx: mint log_idx
  #     edition: edition serial
  @nft_template_token_defaults [index: {<<>>, -1, -1}, txi: nil, log_idx: nil, edition: nil]
  defrecord :nft_template_token, @nft_template_token_defaults

  @type nft_template_token_index :: {pubkey(), template_id(), token_id()}
  @type nft_template_token ::
          record(:nft_template_token,
            index: nft_template_token_index(),
            txi: txi(),
            log_idx: log_idx(),
            edition: String.t()
          )

  # AEX-141 token template
  #     index: {contract pubkey, token_id}, template: template id
  @nft_token_template_defaults [index: {<<>>, -1}, template: nil]
  defrecord :nft_token_template, @nft_token_template_defaults

  @type nft_token_template_index :: {pubkey(), token_id()}
  @type nft_token_template() ::
          record(:nft_token_template,
            index: nft_token_template_index(),
            template: template_id()
          )

  # AEX-141 collection owners
  #     index: {contract pubkey, owner pubkey, token_id}
  @nft_owner_token_defaults [index: nil, unused: nil]
  defrecord :nft_owner_token, @nft_owner_token_defaults

  @type nft_owner_token_index() :: {pubkey(), pubkey(), AeMdw.Aex141.token_id()}
  @type nft_owner_token() :: record(:nft_owner_token, index: nft_owner_token_index())

  # AEX-141 token owner
  #     index: {contract pubkey, token_id}, owner: pubkey
  @nft_token_owner_defaults [index: {<<>>, -1}, owner: <<>>]
  defrecord :nft_token_owner, @nft_token_owner_defaults

  @type nft_token_owner_index() :: {pubkey(), AeMdw.Aex141.token_id()}
  @type nft_token_owner() ::
          record(:nft_token_owner,
            index: nft_token_owner_index(),
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

  @type nft_contract_limits_index() :: pubkey()
  @type nft_contract_limits() ::
          record(:nft_contract_limits,
            index: nft_contract_limits_index(),
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

  @type contract_call_index() :: {txi(), txi()}
  @type contract_call() ::
          record(:contract_call,
            index: contract_call_index(),
            fun: fname(),
            args: [term()],
            result: term(),
            return: term()
          )

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

  @type contract_log_index() :: {txi(), txi(), Contract.event_hash(), non_neg_integer()}
  @type contract_log() ::
          record(:contract_log,
            index: contract_log_index(),
            ext_contract: pubkey() | nil | {:parent_contract_pk, pubkey()},
            args: [term()],
            data: DbContract.log_data()
          )

  # data contract log:
  #     index: {data, call txi, create txi, event hash, log idx}
  @data_contract_log_defaults [
    index: {nil, -1, -1, nil, -1},
    unused: nil
  ]
  defrecord :data_contract_log, @data_contract_log_defaults

  @type data_contract_log_index() ::
          {DbContract.log_data(), txi(), txi(), Contract.event_hash(), non_neg_integer()}
  @type data_contract_log() :: record(:data_contract_log, index: data_contract_log_index())

  # evt contract log:
  #     index: {event hash, call txi, create txi, log idx}
  @evt_contract_log_defaults [
    index: {nil, -1, -1, -1},
    unused: nil
  ]
  defrecord :evt_contract_log, @evt_contract_log_defaults

  @type evt_contract_log_index() :: {Contract.event_hash(), txi(), txi(), non_neg_integer()}
  @type evt_contract_log() :: record(:evt_contract_log, index: evt_contract_log_index())

  # idx contract log:
  #     index: {call txi, log idx, create_txi, event hash}
  @idx_contract_log_defaults [
    index: {-1, -1, -1, <<>>},
    unused: nil
  ]
  defrecord :idx_contract_log, @idx_contract_log_defaults

  @type idx_contract_log_index() :: {txi(), non_neg_integer(), txi(), Contracts.event_hash()}
  @type idx_contract_log() :: record(:idx_contract_log, index: idx_contract_log_index())

  # aex9 transfer:
  #    index: {from pk, call txi, to pk, amount, log idx}
  @aex9_transfer_defaults [
    index: {nil, -1, nil, -1, -1},
    unused: nil
  ]
  defrecord :aex9_transfer, @aex9_transfer_defaults

  @type aex9_transfer_index() :: {pubkey(), txi(), pubkey(), amount(), non_neg_integer()}
  @type aex9_transfer() :: record(:aex9_transfer, index: aex9_transfer_index())

  # rev aex9 transfer:
  #    index: {to pk, call txi, from pk, amount, log idx}
  @rev_aex9_transfer_defaults [
    index: {nil, -1, nil, -1, -1},
    unused: nil
  ]
  defrecord :rev_aex9_transfer, @rev_aex9_transfer_defaults

  @type rev_aex9_transfer_index() :: {pubkey(), txi(), pubkey(), amount(), non_neg_integer()}
  @type rev_aex9_transfer() :: record(:rev_aex9_transfer, index: rev_aex9_transfer_index())

  # aex9 pair transfer:
  #    index: {from pk, to pk, call txi, amount, log idx}
  @aex9_pair_transfer_defaults [
    index: {nil, nil, -1, -1, -1},
    unused: nil
  ]
  defrecord :aex9_pair_transfer, @aex9_pair_transfer_defaults

  @type aex9_pair_transfer_index() :: {pubkey(), pubkey(), txi(), amount(), non_neg_integer()}
  @type aex9_pair_transfer() :: record(:aex9_pair_transfer, index: aex9_pair_transfer_index())

  # idx aex9 transfer:
  #    index: {call txi, log idx, from pk, to pk, amount}
  @idx_aex9_transfer_defaults [
    index: {-1, -1, nil, nil, -1},
    unused: nil
  ]
  defrecord :idx_aex9_transfer, @idx_aex9_transfer_defaults

  @type idx_aex9_transfer_index() :: {txi(), non_neg_integer(), pubkey(), pubkey(), amount()}
  @type idx_aex9_transfer() :: record(:idx_aex9_transfer, index: idx_aex9_transfer_index())

  # aexn transfer:
  #    index: {:aex9 | :aex141, from pk, call txi, to pk, amount | token_id, log idx}
  @aexn_transfer_defaults [
    index: {nil, <<>>, -1, <<>>, -1, -1},
    contract_pk: <<>>
  ]
  defrecord :aexn_transfer, @aexn_transfer_defaults

  @type aexn_transfer_index() ::
          {aexn_type(), pubkey(), txi(), pubkey(), amount(), non_neg_integer()}
  @type aexn_transfer() ::
          record(:aexn_transfer, index: aexn_transfer_index(), contract_pk: pubkey())

  # rev aexn transfer:
  #    index: {:aex9 | :aex141, to pk, call txi, from pk, amount | token_id, log idx}
  @rev_aexn_transfer_defaults [
    index: {nil, <<>>, -1, <<>>, -1, -1},
    unused: nil
  ]
  defrecord :rev_aexn_transfer, @rev_aexn_transfer_defaults

  @type rev_aexn_transfer_index() ::
          {aexn_type(), pubkey(), txi(), pubkey(), amount(), non_neg_integer()}
  @type rev_aexn_transfer() :: record(:rev_aexn_transfer, index: rev_aexn_transfer_index())

  # aexn pair transfer:
  #    index: {:aex9 | :aex141, from pk, to pk, call txi, amount | token_id, log idx}
  @aexn_pair_transfer_defaults [
    index: {nil, <<>>, <<>>, -1, -1, -1},
    unused: nil
  ]
  defrecord :aexn_pair_transfer, @aexn_pair_transfer_defaults

  @type aexn_pair_transfer_index() ::
          {aexn_type(), pubkey(), pubkey(), txi(), amount(), non_neg_integer()}
  @type aexn_pair_transfer() :: record(:aexn_pair_transfer, index: aexn_pair_transfer_index())

  # aexn contract from transfer:
  #    index: {create_txi, from pk, call txi, to pk, amount | token_id, log idx}
  @aexn_contract_from_transfer_defaults [
    index: {-1, <<>>, <<>>, -1, -1, -1},
    unused: nil
  ]
  defrecord :aexn_contract_from_transfer, @aexn_contract_from_transfer_defaults

  @type aexn_contract_from_transfer_index() ::
          {txi(), pubkey(), txi(), pubkey(), amount(), non_neg_integer()}
  @type aexn_contract_from_transfer() ::
          record(:aexn_contract_from_transfer, index: aexn_contract_from_transfer_index())

  # aexn contract to transfer:
  #    index: {create_txi, to pk, call txi, from pk, amount | token_id, log idx}
  @aexn_contract_to_transfer_defaults [
    index: {-1, <<>>, <<>>, -1, -1, -1},
    unused: nil
  ]
  defrecord :aexn_contract_to_transfer, @aexn_contract_to_transfer_defaults

  @type aexn_contract_to_transfer_index() ::
          {txi(), pubkey(), txi(), pubkey(), amount(), non_neg_integer()}
  @type aexn_contract_to_transfer() ::
          record(:aexn_contract_to_transfer, index: aexn_contract_to_transfer_index())

  # aex9 account presence:
  #    index: {account pk, contract pk}
  #    txi: create or call txi
  @aex9_account_presence_defaults [
    index: {nil, nil},
    txi: -1
  ]
  defrecord :aex9_account_presence, @aex9_account_presence_defaults

  @type aex9_account_presence_index() :: {pubkey(), pubkey()}
  @type aex9_account_presence() ::
          record(:aex9_account_presence,
            index: aex9_account_presence_index(),
            txi: txi()
          )

  # idx_aex9_account_presence:
  #    index: {create or call txi, account pk, contract pk}
  @idx_aex9_account_presence_defaults [
    index: {-1, nil, nil},
    unused: nil
  ]
  defrecord :idx_aex9_account_presence, @idx_aex9_account_presence_defaults

  @type idx_aex9_account_presence_index() :: {txi(), pubkey(), pubkey()}
  @type idx_aex9_account_presence() ::
          record(:idx_aex9_account_presence, index: idx_aex9_account_presence_index())

  # int_contract_call:
  #    index: {call txi, local idx}
  @int_contract_call_defaults [
    index: {-1, -1},
    create_txi: -1,
    fname: "",
    tx: {}
  ]
  defrecord :int_contract_call, @int_contract_call_defaults

  @type int_contract_call_index() :: {txi(), Contract.local_idx()}
  @type int_contract_call ::
          record(:int_contract_call,
            index: int_contract_call_index(),
            create_txi: txi() | -1,
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

  @type grp_int_contract_call_index() :: {txi(), txi(), non_neg_integer()}
  @type grp_int_contract_call() ::
          record(:grp_int_contract_call, index: grp_int_contract_call_index())

  # fname_int_contract_call:
  #    index: {fname, call txi, local idx}
  @fname_int_contract_call_defaults [
    index: {"", -1, -1},
    unused: nil
  ]
  defrecord :fname_int_contract_call, @fname_int_contract_call_defaults

  @type fname_int_contract_call_index() :: {fname(), txi(), txi()}
  @type fname_int_contract_call() ::
          record(:fname_int_contract_call, index: fname_int_contract_call_index())

  # fname_grp_int_contract_call:
  #    index: {fname, create txi, call txi, local idx}
  @fname_grp_int_contract_call_defaults [
    index: {"", -1, -1, -1},
    unused: nil
  ]
  defrecord :fname_grp_int_contract_call, @fname_grp_int_contract_call_defaults

  @type fname_grp_int_contract_call_index() :: {fname(), txi(), txi(), non_neg_integer()}
  @type fname_grp_int_contract_call() ::
          record(:fname_grp_int_contract_call, index: fname_grp_int_contract_call_index())

  ##
  # id_int_contract_call:
  #    index: {id pk, id pos, call txi, local idx}
  @id_int_contract_call_defaults [
    index: {<<>>, -1, -1, -1},
    unused: nil
  ]
  defrecord :id_int_contract_call, @id_int_contract_call_defaults

  @type id_int_contract_call_index() :: {pubkey(), non_neg_integer(), txi(), non_neg_integer()}
  @type id_int_contract_call() ::
          record(:id_int_contract_call, index: id_int_contract_call_index())

  # grp_id_int_contract_call:
  #    index: {create txi, id pk, id pos, call txi, local idx}
  @grp_id_int_contract_call_defaults [
    index: {-1, <<>>, -1, -1, -1},
    unused: nil
  ]
  defrecord :grp_id_int_contract_call, @grp_id_int_contract_call_defaults

  @type grp_id_int_contract_call_index() ::
          {txi(), pubkey(), non_neg_integer(), txi(), non_neg_integer()}
  @type grp_id_int_contract_call() ::
          record(:grp_id_int_contract_call, index: grp_id_int_contract_call_index())

  # id_fname_int_contract_call:
  #    index: {id pk, fname, id pos, call txi, local idx}
  @id_fname_int_contract_call_defaults [
    index: {<<>>, "", -1, -1, -1},
    unused: nil
  ]
  defrecord :id_fname_int_contract_call, @id_fname_int_contract_call_defaults

  @type id_fname_int_contract_call_index() ::
          {pubkey(), fname(), non_neg_integer(), txi(), non_neg_integer()}
  @type id_fname_int_contract_call() ::
          record(:id_fname_int_contract_call, index: id_fname_int_contract_call_index())

  # grp_id_fname_int_contract_call:
  #    index: {create txi, id pk, fname, id pos, call txi, local idx}
  @grp_id_fname_int_contract_call_defaults [
    index: {-1, <<>>, "", -1, -1, -1},
    unused: nil
  ]
  defrecord :grp_id_fname_int_contract_call, @grp_id_fname_int_contract_call_defaults

  @type grp_id_fname_int_contract_call_index() ::
          {txi(), pubkey(), fname(), non_neg_integer(), txi(), non_neg_integer()}
  @type grp_id_fname_int_contract_call() ::
          record(:grp_id_fname_int_contract_call, index: grp_id_fname_int_contract_call_index())

  # int_transfer_tx:
  #   index: {{height, -1 (generation related transfer OR >=0 {txi, idx} (tx related transfer)}, kind, target, ref txi}
  @int_transfer_tx_defaults [
    index: {{-1, -1}, nil, <<>>, -1},
    amount: 0
  ]
  defrecord :int_transfer_tx, @int_transfer_tx_defaults

  @type int_transfer_tx_index() ::
          {bi_txi_idx() | {txi_idx() | -1}, IntTransfer.kind(), pubkey(), txi_idx() | -1}
  @type int_transfer_tx() ::
          record(:int_transfer_tx,
            index: int_transfer_tx_index(),
            amount: amount()
          )

  # kind_int_transfer_tx:
  #  index: {kind, block_index, target, ref txi}
  @kind_int_transfer_tx_defaults [
    index: {nil, {-1, -1}, <<>>, -1},
    unused: nil
  ]
  defrecord :kind_int_transfer_tx, @kind_int_transfer_tx_defaults

  @type kind_int_transfer_tx_index() :: {IntTransfer.kind(), bi_txi(), pubkey(), txi() | -1}
  @type kind_int_transfer_tx() ::
          record(:kind_int_transfer_tx,
            index: kind_int_transfer_tx_index()
          )

  # target_kind_int_transfer_tx
  #  index: {target, kind, block_index, ref txi}
  @target_kind_int_transfer_tx_defaults [
    index: {<<>>, <<>>, {-1, -1}, -1},
    unused: nil
  ]
  defrecord :target_kind_int_transfer_tx, @target_kind_int_transfer_tx_defaults

  @type target_kind_int_transfer_tx_index() ::
          {pubkey(), IntTransfer.kind(), bi_txi(), txi() | -1}
  @type target_kind_int_transfer_tx() ::
          record(:target_kind_int_transfer_tx, index: target_kind_int_transfer_tx_index())

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

  @type delta_stat_index() :: Blocks.height()
  @type delta_stat ::
          record(:delta_stat,
            index: delta_stat_index(),
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

  @type total_stat_index() :: Blocks.height()
  @type total_stat ::
          record(:total_stat,
            index: total_stat_index(),
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

  @type stat_index() :: atom() | {atom(), pubkey()} | {atom(), pubkey(), template_id()}
  @type stat() :: record(:stat, index: stat_index(), payload: term())

  @miner_defaults [:index, :total_reward]
  defrecord :miner, @miner_defaults

  @type miner_index() :: pubkey()
  @type miner() :: record(:miner, index: miner_index(), total_reward: non_neg_integer())

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
      AeMdw.Db.Model.Aex9InitialSupply,
      AeMdw.Db.Model.Aex9ContractBalance,
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
      AeMdw.Db.Model.NftTokenTemplate,
      AeMdw.Db.Model.NftTemplate,
      AeMdw.Db.Model.NftTemplateToken
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
      AeMdw.Db.Model.BalanceAccount,
      AeMdw.Db.Model.AsyncTask,
      AeMdw.Db.Model.AsyncTasks,
      AeMdw.Db.Model.Migrations
    ]
  end

  @spec record(atom()) :: atom()
  def record(AeMdw.Db.Model.BalanceAccount), do: :balance_account
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
  def record(AeMdw.Db.Model.Aex9InitialSupply), do: :aex9_initial_supply
  def record(AeMdw.Db.Model.Aex9ContractBalance), do: :aex9_contract_balance
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
  def record(AeMdw.Db.Model.NftTokenTemplate), do: :nft_token_template
  def record(AeMdw.Db.Model.NftTemplate), do: :nft_template
  def record(AeMdw.Db.Model.NftTemplateToken), do: :nft_template_token
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

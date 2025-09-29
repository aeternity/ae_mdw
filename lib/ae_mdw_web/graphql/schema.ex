defmodule AeMdwWeb.GraphQL.Schema do
  @moduledoc """
  Initial GraphQL schema skeleton. Extend with additional types and fields incrementally.
  """
  use Absinthe.Schema

  # Simple scalar mapping for IDs is fine for now
  import_types Absinthe.Type.Custom

  query do
    @desc "Paginated names (initial release). Supports filters owned_by, state, prefix and order_by"
    field :names, :name_page do
      arg :cursor, :string
      arg :limit, :integer, default_value: 20
      arg :order_by, :name_order, default_value: :expiration
      arg :owned_by, :string
      arg :state, :name_state
      arg :prefix, :string
      resolve &AeMdwWeb.GraphQL.Resolvers.NameResolver.names/3
    end

    @desc "Count names (filters owned_by, state, prefix)"
    field :names_count, :integer do
      arg :owned_by, :string
      arg :state, :name_state
      arg :prefix, :string
      resolve &AeMdwWeb.GraphQL.Resolvers.NameResolver.names_count/3
    end

    @desc "Fetch a single name or auction by plain name or name hash"
    field :name, :name do
      arg :id, non_null(:string)
      resolve &AeMdwWeb.GraphQL.Resolvers.NameResolver.name/3
    end

    @desc "History for a name (claims, updates, transfers, revoke, expire)"
    field :name_history, :name_history_page do
      arg :id, non_null(:string)
      arg :cursor, :string
      arg :limit, :integer, default_value: 20
      resolve &AeMdwWeb.GraphQL.Resolvers.NameResolver.name_history/3
    end

    @desc "Claims for a name"
    field :name_claims, :name_history_page do
      arg :id, non_null(:string)
      arg :cursor, :string
      arg :limit, :integer, default_value: 20
      resolve &AeMdwWeb.GraphQL.Resolvers.NameResolver.name_claims/3
    end

    @desc "Updates for a name"
    field :name_updates, :name_history_page do
      arg :id, non_null(:string)
      arg :cursor, :string
      arg :limit, :integer, default_value: 20
      resolve &AeMdwWeb.GraphQL.Resolvers.NameResolver.name_updates/3
    end

    @desc "Transfers for a name"
    field :name_transfers, :name_history_page do
      arg :id, non_null(:string)
      arg :cursor, :string
      arg :limit, :integer, default_value: 20
      resolve &AeMdwWeb.GraphQL.Resolvers.NameResolver.name_transfers/3
    end

    @desc "Fetch a single auction"
    field :auction, :auction do
      arg :id, non_null(:string)
      resolve &AeMdwWeb.GraphQL.Resolvers.NameResolver.auction/3
    end

    @desc "Paginated auctions"
    field :auctions, :auction_page do
      arg :cursor, :string
      arg :limit, :integer, default_value: 20
      arg :order_by, :auction_order, default_value: :expiration
      resolve &AeMdwWeb.GraphQL.Resolvers.NameResolver.auctions/3
    end

    @desc "Search names & auctions (only supports prefix + optional lifecycle filters)"
    field :search_names, :search_name_page do
      arg :prefix, :string
      arg :only, list_of(:string), description: "Allowed values: active, inactive, auction"
      arg :cursor, :string
      arg :limit, :integer, default_value: 20
      resolve &AeMdwWeb.GraphQL.Resolvers.NameResolver.search_names/3
    end

    @desc "Account pointees (names pointing to account via AENS pointers)"
    field :account_pointees, :pointee_page do
      arg :id, non_null(:string)
      arg :cursor, :string
      arg :limit, :integer, default_value: 20
      resolve &AeMdwWeb.GraphQL.Resolvers.NameResolver.account_pointees/3
    end

    @desc "Name pointees (active & inactive pointer entries for a given name hash)"
    field :name_pointees, :name_pointees do
      arg :id, non_null(:string)
      resolve &AeMdwWeb.GraphQL.Resolvers.NameResolver.name_pointees/3
    end

    @desc "Fetch a key block by height or hash"
    field :key_block, :key_block do
      arg :id, non_null(:string), description: "Height (integer as string) or key block hash"
      resolve &AeMdwWeb.GraphQL.Resolvers.BlockResolver.key_block/3
    end

    @desc "Fetch a micro block by its hash"
    field :micro_block, :micro_block do
      arg :hash, non_null(:string)
      resolve &AeMdwWeb.GraphQL.Resolvers.BlockResolver.micro_block/3
    end

    @desc "Paginated key blocks (optionally by generation range)"
    field :key_blocks, :key_block_page do
      arg :cursor, :string
      arg :limit, :integer, default_value: 20
      arg :from_height, :integer
      arg :to_height, :integer
      resolve &AeMdwWeb.GraphQL.Resolvers.BlockResolver.key_blocks/3
    end

    @desc "Current sync status (partial=true means middleware still syncing)"
    field :sync_status, :sync_status do
      resolve fn _, _, %{context: ctx} ->
        state = Map.get(ctx, :state)
        case state do
          %AeMdw.Db.State{} = st ->
            case AeMdw.Db.Util.last_gen(st) do
              {:ok, h} -> {:ok, %{last_synced_height: h, partial: false}}
              :none -> {:ok, %{last_synced_height: 0, partial: true}}
            end
          _ -> {:ok, %{last_synced_height: 0, partial: true}}
        end
      end
    end

    @desc "Fetch a transaction by hash (or numeric index as string)"
    field :transaction, :transaction do
      arg :id, non_null(:string), description: "Transaction hash or numeric index"
      resolve &AeMdwWeb.GraphQL.Resolvers.TransactionResolver.transaction/3
    end

    @desc "Count transactions (optionally filtered)"
    field :transactions_count, :integer do
      arg :from_txi, :integer
      arg :to_txi, :integer
      arg :from_height, :integer
      arg :to_height, :integer
      arg :account, :string
      arg :type, :string
      arg :filter, :transaction_filter
      resolve &AeMdwWeb.GraphQL.Resolvers.TransactionResolver.transactions_count/3
    end

    @desc "Paginated transactions (backward direction); minimal filters supported"
    field :transactions, :transaction_page do
      arg :cursor, :string, description: "Opaque cursor (tx index)"
      arg :limit, :integer, default_value: 20
  # legacy txi range (still accepted)
  arg :from_txi, :integer
  arg :to_txi, :integer
  # new height based range
  arg :from_height, :integer
  arg :to_height, :integer
      arg :account, :string, description: "Account public key filter"
      arg :type, :string, description: "Transaction type filter (e.g. spend_tx)"
  arg :filter, :transaction_filter, description: "Compound filter object {account,type,from_height,to_height}"
      resolve &AeMdwWeb.GraphQL.Resolvers.TransactionResolver.transactions/3
    end

    @desc "Transactions contained in a micro block"
    field :micro_block_transactions, :transaction_page do
      arg :hash, non_null(:string)
      arg :cursor, :string
      arg :limit, :integer, default_value: 20
      arg :account, :string
      arg :type, :string
      resolve &AeMdwWeb.GraphQL.Resolvers.TransactionResolver.micro_block_transactions/3
    end

    @desc "Micro blocks inside a key block"
    field :key_block_micro_blocks, :micro_block_page do
      arg :id, non_null(:string), description: "Key block height or hash"
      arg :cursor, :string
      arg :limit, :integer, default_value: 20
      resolve &AeMdwWeb.GraphQL.Resolvers.TransactionResolver.key_block_micro_blocks/3
    end

    @desc "Pending transactions (node mempool)"
    field :pending_transactions, :transaction_page do
      arg :cursor, :string
      arg :limit, :integer, default_value: 20
      resolve &AeMdwWeb.GraphQL.Resolvers.TransactionResolver.pending_transactions/3
    end

    @desc "Count of pending transactions (node mempool)"
    field :pending_transactions_count, :integer do
      resolve &AeMdwWeb.GraphQL.Resolvers.TransactionResolver.pending_transactions_count/3
    end

    @desc "Fetch an account by its public key"
    field :account, :account do
      arg :id, non_null(:string)
      resolve &AeMdwWeb.GraphQL.Resolvers.AccountResolver.account/3
    end

    @desc "Paginated accounts (backward by pubkey); only nextCursor supported for now"
    field :accounts, :account_page do
      arg :cursor, :string
      arg :limit, :integer, default_value: 20
      resolve &AeMdwWeb.GraphQL.Resolvers.AccountResolver.accounts/3
    end

    @desc "Names owned by an account"
    field :account_names, :name_page do
      arg :id, non_null(:string)
      arg :cursor, :string
      arg :limit, :integer, default_value: 20
      resolve &AeMdwWeb.GraphQL.Resolvers.AccountResolver.account_names/3
    end

    @desc "AEX9 token balances for an account"
    field :account_aex9_balances, :aex9_balance_page do
      arg :id, non_null(:string)
      arg :cursor, :string
      arg :limit, :integer, default_value: 50
      resolve &AeMdwWeb.GraphQL.Resolvers.AccountResolver.account_aex9_balances/3
    end

    @desc "Richer sync / chain status"
    field :status, :status do
      resolve fn _, _, %{context: ctx} ->
        state = Map.get(ctx, :state)
        case state do
          %AeMdw.Db.State{} = st ->
            last_h = case AeMdw.Db.Util.last_gen(st) do {:ok, h} -> h; :none -> 0 end
            partial = last_h == 0
            kb = if last_h > 0 do
              case AeMdw.Blocks.fetch_key_block(st, Integer.to_string(last_h)) do
                {:ok, blk} -> blk
                _ -> %{}
              end
            else
              %{}
            end
            total_txs = case AeMdw.Txs.count(st, nil, %{}) do {:ok, c} -> c; _ -> 0 end
            pending = try do AeMdw.Node.Db.pending_txs_count() rescue _ -> 0 end
            {:ok, %{
              last_synced_height: last_h,
              last_key_block_hash: Map.get(kb, :hash) || Map.get(kb, "hash"),
              last_key_block_time: Map.get(kb, :time) || Map.get(kb, "time"),
              total_transactions: total_txs,
              pending_transactions: pending,
              partial: partial
            }}
          _ -> {:ok, %{last_synced_height: 0, last_key_block_hash: nil, last_key_block_time: nil, total_transactions: 0, pending_transactions: 0, partial: true}}
        end
      end
    end
  end

  object :key_block do
    field :hash, non_null(:string)
    field :height, non_null(:integer)
    field :time, non_null(:integer)
  field :miner, :string, resolve: fn blk, _, _ -> {:ok, blk[:beneficiary] || blk["beneficiary"]} end
    field :micro_blocks_count, :integer
    field :transactions_count, :integer
    field :beneficiary_reward, :integer
  # extra enrichment
  field :info, :string, description: "Consensus protocol / version JSON (serialized)"
  field :pow, :string, description: "Proof-of-work info if present"
  field :nonce, :string
  field :version, :integer
  field :target, :integer
  field :state_hash, :string
  field :prev_key_hash, :string
  field :prev_hash, :string
  field :beneficiary, :string
  end

  object :micro_block do
    field :hash, non_null(:string)
    field :height, non_null(:integer)
    field :time, non_null(:integer)
    field :micro_block_index, :integer
    field :transactions_count, :integer
    field :gas, :integer
  # enrichment
  field :pof_hash, :string
  field :prev_hash, :string
  field :state_hash, :string
  field :txs_hash, :string
  field :signature, :string
  field :miner, :string
  end

  object :key_block_page do
    field :prev_cursor, :string
    field :next_cursor, :string
    field :data, list_of(:key_block)
  end

  object :micro_block_page do
    field :prev_cursor, :string
    field :next_cursor, :string
    field :data, list_of(:micro_block)
  end

  object :transaction_page do
    field :prev_cursor, :string
    field :next_cursor, :string
    field :data, list_of(:transaction)
  end

  object :account_page do
    field :prev_cursor, :string
    field :next_cursor, :string
    field :data, list_of(:account)
  end

  object :name do
    field :name, :string
    field :active, :boolean
    field :expire_height, :integer
  field :hash, :string
  field :active_from, :integer
  field :approximate_activation_time, :integer
  field :approximate_expire_time, :integer
  field :name_fee, :integer
  field :claims_count, :integer
  field :auction_timeout, :integer
  field :revoke, :string, description: "Revoke transaction (tx hash or expanded JSON if expand requested)"
  field :pointers, list_of(:name_pointer)
  field :ownership, :name_ownership
  field :auction, :string, description: "Auction data (JSON string) if still in auction"
  end

  object :name_page do
    field :prev_cursor, :string
    field :next_cursor, :string
    field :data, list_of(:name)
  end

  object :name_history_item do
    field :active_from, :integer
    field :expired_at, :integer
    field :height, :integer
    field :block_hash, :string
    field :source_tx_hash, :string
    field :source_tx_type, :string
    field :internal_source, :boolean
    field :tx, :string, description: "Source chain transaction (JSON)"
  end

  object :name_history_page do
    field :prev_cursor, :string
    field :next_cursor, :string
    field :data, list_of(:name_history_item)
  end

  object :auction do
    field :name, :string
    field :activation_time, :integer
    field :auction_end, :integer
    field :approximate_expire_time, :integer
    field :name_fee, :integer
    field :claims_count, :integer
    field :last_bid, :string, description: "JSON with last bid tx"
  end

  object :auction_page do
    field :prev_cursor, :string
    field :next_cursor, :string
    field :data, list_of(:auction)
  end

  object :search_name_entry do
    field :type, :string
    field :name, :string
    field :active, :boolean
    field :auction, :auction
  end

  object :search_name_page do
    field :prev_cursor, :string
    field :next_cursor, :string
    field :data, list_of(:search_name_entry)
  end

  object :pointee do
    field :name, :string
    field :active, :boolean
    field :key, :string
    field :block_height, :integer
    field :block_hash, :string
    field :block_time, :integer
    field :source_tx_hash, :string
    field :source_tx_type, :string
    field :tx, :string
  end

  object :pointee_page do
    field :prev_cursor, :string
    field :next_cursor, :string
    field :data, list_of(:pointee)
  end

  object :name_pointees do
    field :active, list_of(:name_pointer)
    field :inactive, list_of(:name_pointer)
  end

  object :name_pointer do
    field :key, :string
    field :id, :string
  end

  object :name_ownership do
    field :current, :string
    field :original, :string
  end

  object :aex9_balance do
    field :contract_id, :string
    field :amount, :big_int
  end

  object :aex9_balance_page do
    field :prev_cursor, :string
    field :next_cursor, :string
    field :data, list_of(:aex9_balance)
  end

  object :transaction do
    field :hash, :string
    field :block_hash, :string
    field :block_height, :integer
    field :micro_index, :integer
    field :micro_time, :integer
    field :tx_index, :integer
    field :signatures, list_of(:string)
  field :tx, :string, description: "Underlying tx object encoded as JSON string"
  # enrichment (common tx metadata)
  field :fee, :integer
  field :type, :string
  field :gas, :integer
  field :gas_price, :integer
  field :nonce, :integer
  field :sender_id, :string
  field :recipient_id, :string
  field :amount, :integer
  field :ttl, :integer
  field :payload, :string
  end

  object :account do
    field :id, non_null(:string)
    # Large balance uses custom BigInt scalar (no 32-bit restriction)
    field :balance, :big_int
    field :creation_time, :integer
  field :nonce, :integer
  field :names_count, :integer
  field :activities_count, :integer, description: "Number of recorded activity intervals"
  end

  # Custom scalar capable of representing arbitrarily large integers
  scalar :big_int, name: "BigInt" do
    parse fn
      %Absinthe.Blueprint.Input.Integer{value: v} -> {:ok, v}
      %Absinthe.Blueprint.Input.String{value: v} ->
        case Integer.parse(v) do
          {int, ""} -> {:ok, int}
          _ -> :error
        end
      _ -> :error
    end

    serialize fn
      v when is_integer(v) -> v
      v when is_binary(v) ->
        case Integer.parse(v) do
          {int, ""} -> int
          _ -> raise Absinthe.SerializationError, "Invalid BigInt binary"
        end
      other -> raise Absinthe.SerializationError, "Invalid BigInt value: #{inspect(other)}"
    end
  end

  # Generic JSON passthrough scalar
  scalar :json, name: "JSON" do
    parse fn
      %{value: value} -> {:ok, value}
      _ -> :error
    end

    serialize fn value -> value end
  end

  input_object :transaction_filter do
    field :account, :string
    field :type, :string
    field :from_height, :integer
    field :to_height, :integer
  end

  enum :name_order do
    value :expiration
    value :activation
    value :deactivation
    value :name
  end

  enum :name_state do
    value :active
    value :inactive
  end

  enum :auction_order do
    value :expiration
    value :name
  end

  object :status do
    field :last_synced_height, non_null(:integer)
    field :last_key_block_hash, :string
    field :last_key_block_time, :integer
    field :total_transactions, :integer
    field :pending_transactions, :integer
    field :partial, non_null(:boolean)
  end

  object :sync_status do
    field :last_synced_height, non_null(:integer)
    field :partial, non_null(:boolean)
  end

  def context(ctx) do
    ctx = case ctx do
      %{conn: %{assigns: %{state: state}}} -> Map.put(ctx, :state, state)
      _ -> ctx
    end

    # If no state assigned (early sync), attempt to fetch current mem_state lazily
    if Map.get(ctx, :state) do
      ctx
    else
      case AeMdw.Db.State.mem_state() do
        %AeMdw.Db.State{} = st -> Map.put(ctx, :state, st)
        _ -> ctx
      end
    end
  end

  # Add plugins/2 when Dataloader or complexity analysis middleware is introduced.
end

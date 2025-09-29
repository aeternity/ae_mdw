defmodule AeMdwWeb.GraphQL.Schema do
  @moduledoc """
  Initial GraphQL schema skeleton. Extend with additional types and fields incrementally.
  """
  use Absinthe.Schema

  alias AeMdwWeb.GraphQL.Resolvers.ContractResolver

  # Simple scalar mapping for IDs is fine for now
  import_types Absinthe.Type.Custom

  query do
    @desc "Fetch a contract by its public key (id)"
    field :contract, :contract do
      arg :id, non_null(:id)
      resolve &ContractResolver.contract/3
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
  end

  object :contract do
    field :id, non_null(:id)
    field :aexn_type, :string, description: "Token standard type if applicable (aex9 / aex141)"
    field :meta_name, :string, description: "Token name (if aexn and present)"
    field :meta_symbol, :string, description: "Token symbol (if aexn and present)"
  end

  object :key_block do
    field :hash, non_null(:string)
    field :height, non_null(:integer)
    field :time, non_null(:integer)
  field :miner, :string, resolve: fn blk, _, _ -> {:ok, blk[:beneficiary] || blk["beneficiary"]} end
    field :micro_blocks_count, :integer
    field :transactions_count, :integer
    field :beneficiary_reward, :integer
  end

  object :micro_block do
    field :hash, non_null(:string)
    field :height, non_null(:integer)
    field :time, non_null(:integer)
    field :micro_block_index, :integer
    field :transactions_count, :integer
    field :gas, :integer
  end

  object :key_block_page do
    field :prev_cursor, :string
    field :next_cursor, :string
    field :data, list_of(:key_block)
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

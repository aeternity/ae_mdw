defmodule AeMdwWeb.GraphQL.Schema.Queries.StatusQueries do
  use Absinthe.Schema.Notation

  object :status_queries do
    @desc "Current sync status (partial=true means middleware still syncing)"
    field :sync_status, :sync_status do
      resolve(fn _, _, %{context: ctx} ->
        state = Map.get(ctx, :state)

        case state do
          %AeMdw.Db.State{} = st ->
            case AeMdw.Db.Util.last_gen(st) do
              {:ok, h} -> {:ok, %{last_synced_height: h, partial: false}}
              :none -> {:ok, %{last_synced_height: 0, partial: true}}
            end

          _ ->
            {:ok, %{last_synced_height: 0, partial: true}}
        end
      end)
    end

    @desc "Richer sync / chain status"
    field :status, :status do
      resolve(fn _, _, %{context: ctx} ->
        state = Map.get(ctx, :state)

        case state do
          %AeMdw.Db.State{} = st ->
            last_h =
              case AeMdw.Db.Util.last_gen(st) do
                {:ok, h} -> h
                :none -> 0
              end

            partial = last_h == 0

            kb =
              if last_h > 0 do
                case AeMdw.Blocks.fetch_key_block(st, Integer.to_string(last_h)) do
                  {:ok, blk} -> blk
                  _ -> %{}
                end
              else
                %{}
              end

            total_txs =
              case AeMdw.Txs.count(st, nil, %{}) do
                {:ok, c} -> c
                _ -> 0
              end

            pending =
              try do
                AeMdw.Node.Db.pending_txs_count()
              rescue
                _ -> 0
              end

            {:ok,
             %{
               last_synced_height: last_h,
               last_key_block_hash: Map.get(kb, :hash) || Map.get(kb, "hash"),
               last_key_block_time: Map.get(kb, :time) || Map.get(kb, "time"),
               total_transactions: total_txs,
               pending_transactions: pending,
               partial: partial
             }}

          _ ->
            {:ok,
             %{
               last_synced_height: 0,
               last_key_block_hash: nil,
               last_key_block_time: nil,
               total_transactions: 0,
               pending_transactions: 0,
               partial: true
             }}
        end
      end)
    end
  end
end

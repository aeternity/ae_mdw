defmodule AeMdwWeb.GraphQL.Resolvers.BlockResolver do
  alias AeMdw.Blocks
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def key_blocks(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_h = Map.get(args, :from_height)
    to_h = Map.get(args, :to_height)
    scope = Helpers.make_scope(from_h, to_h)

    case Blocks.fetch_key_blocks(state, direction, scope, cursor, limit) do
      {:ok, {prev, blocks, next}} ->
        {:ok,
         %{
           prev_cursor: Helpers.cursor_val(prev),
           next_cursor: Helpers.cursor_val(next),
           data: blocks |> Enum.map(&normalize_key_block/1)
         }}

      {:error, err} ->
        {:error, ErrInput.message(err)}
    end
  end

  def key_block(_p, %{height: height}, %{context: %{state: state}}) do
    key_block_by_id(state, "#{height}")
  end

  def key_block(_p, %{hash: hash}, %{context: %{state: state}}) do
    key_block_by_id(state, hash)
  end

  def micro_block(_p, %{hash: hash}, %{context: %{state: state}}) do
    case Blocks.fetch_micro_block(state, hash) do
      {:ok, block} -> {:ok, normalize_micro_block(block)}
      {:error, err} -> {:error, ErrInput.message(err)}
    end
  end

  defp key_block_by_id(state, id) do
    case Blocks.fetch_key_block(state, id) do
      {:ok, block} -> {:ok, normalize_key_block(block)}
      {:error, err} -> {:error, ErrInput.message(err)}
    end
  end

  defp normalize_key_block(block) do
    # TODO: do we need to check for both atom and string keys here?
    %{
      transactions_count:
        Map.get(block, :transactions_count) || Map.get(block, "transactions_count"),
      micro_blocks_count:
        Map.get(block, :micro_blocks_count) || Map.get(block, "micro_blocks_count"),
      beneficiary_reward:
        Map.get(block, :beneficiary_reward) || Map.get(block, "beneficiary_reward"),
      beneficiary: Map.get(block, :beneficiary) || Map.get(block, "beneficiary"),
      flags: Map.get(block, :flags) || Map.get(block, "flags"),
      hash: Map.get(block, :hash) || Map.get(block, "hash"),
      height: Map.get(block, :height) || Map.get(block, "height") || Map.get(block, :generation),
      info: Map.get(block, :info) || Map.get(block, "info"),
      miner: Map.get(block, :miner) || Map.get(block, "miner"),
      nonce: Map.get(block, :nonce) || Map.get(block, "nonce"),
      pow: Map.get(block, :pow) || Map.get(block, "pow"),
      prev_hash: Map.get(block, :prev_hash) || Map.get(block, "prev_hash"),
      prev_key_hash: Map.get(block, :prev_key_hash) || Map.get(block, "prev_key_hash"),
      state_hash: Map.get(block, :state_hash) || Map.get(block, "state_hash"),
      target: Map.get(block, :target) || Map.get(block, "target"),
      time: Map.get(block, :time) || Map.get(block, "time"),
      version: Map.get(block, :version) || Map.get(block, "version")
    }
  end

  defp normalize_micro_block(block) do
    # TODO: do we need to check for both atom and string keys here?
    %{
      gas: Map.get(block, :gas) || Map.get(block, "gas"),
      transactions_count:
        Map.get(block, :transactions_count) || Map.get(block, "transactions_count"),
      micro_block_index:
        Map.get(block, :micro_block_index) || Map.get(block, "micro_block_index"),
      flags: Map.get(block, :flags) || Map.get(block, "flags"),
      hash: Map.get(block, :hash) || Map.get(block, "hash"),
      height: Map.get(block, :height) || Map.get(block, "height"),
      pof_hash: Map.get(block, :pof_hash) || Map.get(block, "pof_hash"),
      prev_hash: Map.get(block, :prev_hash) || Map.get(block, "prev_hash"),
      prev_key_hash: Map.get(block, :prev_key_hash) || Map.get(block, "prev_key_hash"),
      signature: Map.get(block, :signature) || Map.get(block, "signature"),
      state_hash: Map.get(block, :state_hash) || Map.get(block, "state_hash"),
      time: Map.get(block, :time) || Map.get(block, "time"),
      txs_hash: Map.get(block, :txs_hash) || Map.get(block, "txs_hash"),
      version: Map.get(block, :version) || Map.get(block, "version")
    }
  end
end

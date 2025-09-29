defmodule AeMdwWeb.GraphQL.Resolvers.BlockResolver do
  @moduledoc """
  Block related resolvers (key blocks and micro blocks).
  """
  alias AeMdw.Blocks
  alias AeMdw.Error.Input, as: ErrInput

  @spec key_block(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def key_block(_p, %{id: id}, %{context: %{state: state}}) when not is_nil(state) do
    case Blocks.fetch_key_block(state, id) do
      {:ok, block} -> {:ok, normalize_key_block(block)}
      {:error, %ErrInput.NotFound{}} -> {:error, "key_block_not_found"}
      {:error, _} -> {:error, "key_block_error"}
    end
  end
  def key_block(_p, %{id: _id}, _res), do: {:error, "partial_state_unavailable"}

  @spec micro_block(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def micro_block(_p, %{hash: hash}, %{context: %{state: state}}) when not is_nil(state) do
    case Blocks.fetch_micro_block(state, hash) do
      {:ok, block} -> {:ok, normalize_micro_block(block)}
      {:error, %ErrInput.NotFound{}} -> {:error, "micro_block_not_found"}
      {:error, _} -> {:error, "micro_block_error"}
    end
  end
  def micro_block(_p, _args, _res), do: {:error, "partial_state_unavailable"}

  @spec key_blocks(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def key_blocks(_p, args, %{context: %{state: state}}) when not is_nil(state) do
    limit = clamp_limit(Map.get(args, :limit, 20))
    cursor = Map.get(args, :cursor)
    from_h = Map.get(args, :from_height)
    to_h = Map.get(args, :to_height)

    scope =
      cond do
        from_h && to_h -> {:gen, from_h..to_h}
        to_h && is_nil(from_h) -> {:gen, 0..to_h}
        from_h && is_nil(to_h) -> {:gen, from_h..from_h}
        true -> nil
      end

    case Blocks.fetch_key_blocks(state, :backward, scope, cursor, limit) do
      {:ok, {prev, blocks, next}} ->
        data =
          blocks
          |> Enum.map(&normalize_key_block/1)
          |> Enum.filter(fn
            %{height: h, hash: _} when is_integer(h) -> true
            _ -> false
          end)

        if blocks != [] and data == [] do
          {:error, "key_blocks_error"}
        else
          {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: data}}
        end

      {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
      {:error, %ErrInput.Scope{}} -> {:error, "invalid_scope"}
      {:error, _} -> {:error, "key_blocks_error"}
    end
  end
  # missing state variants (check cursor first for more specific error)
  def key_blocks(_p, %{cursor: cursor}, _res) when is_binary(cursor) do
    case Integer.parse(cursor) do
      {_n, ""} -> {:error, "partial_state_unavailable"}
      _ -> {:error, "invalid_cursor"}
    end
  end
  def key_blocks(_, _, _), do: {:error, "partial_state_unavailable"}

  defp normalize_key_block(block) do
    # Support both string and atom keys depending on upstream serialization
  hash = Map.get(block, :hash) || Map.get(block, "hash")
  height = Map.get(block, :height) || Map.get(block, "height") || Map.get(block, :generation)
  time = Map.get(block, :time) || Map.get(block, "time")
  beneficiary = Map.get(block, :beneficiary) || Map.get(block, "beneficiary")
  microc = Map.get(block, :micro_blocks_count) || Map.get(block, "micro_blocks_count")
  txc = Map.get(block, :transactions_count) || Map.get(block, "transactions_count")
  reward = Map.get(block, :beneficiary_reward) || Map.get(block, "beneficiary_reward")

    if is_nil(height) or is_nil(hash) or is_nil(time) do
      # Return a sentinel empty map; caller should filter out
      %{}
    else
      %{
        hash: hash,
        height: height,
        time: time,
        beneficiary: beneficiary,
        micro_blocks_count: microc,
        transactions_count: txc,
        beneficiary_reward: reward
      }
    end
  end

  defp normalize_micro_block(block) do
  hash = Map.get(block, :hash) || Map.get(block, "hash")
  height = Map.get(block, :height) || Map.get(block, "height")
  time = Map.get(block, :time) || Map.get(block, "time")
  mbi = Map.get(block, :micro_block_index) || Map.get(block, "micro_block_index")
  txc = Map.get(block, :transactions_count) || Map.get(block, "transactions_count")
  gas = Map.get(block, :gas) || Map.get(block, "gas")
    if is_nil(height) or is_nil(hash) or is_nil(time) do
      %{}
    else
      %{
        hash: hash,
        height: height,
        time: time,
        micro_block_index: mbi,
        transactions_count: txc,
        gas: gas
      }
    end
  end

  defp cursor_val(nil), do: nil
  defp cursor_val({val, _rev}), do: val
  defp clamp_limit(l) when is_integer(l) and l > 100, do: 100
  defp clamp_limit(l) when is_integer(l) and l > 0, do: l
  defp clamp_limit(_), do: 20
end

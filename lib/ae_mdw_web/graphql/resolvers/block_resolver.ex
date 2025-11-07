defmodule AeMdwWeb.GraphQL.Resolvers.BlockResolver do
  alias AeMdw.Blocks
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def key_blocks(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)

    case Blocks.fetch_key_blocks(state, direction, scope, cursor, limit) do
      {:ok, {prev, blocks, next}} ->
        {:ok,
         %{
           prev_cursor: Helpers.cursor_val(prev),
           next_cursor: Helpers.cursor_val(next),
           data: blocks |> Enum.map(&Helpers.normalize_map/1)
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

  def micro_blocks(_p, %{height: height} = args, %{context: %{state: state}}) do
    micro_blocks_by_id(state, args, "#{height}")
  end

  def micro_blocks(_p, %{hash: hash} = args, %{context: %{state: state}}) do
    micro_blocks_by_id(state, args, hash)
  end

  def micro_blocks_by_id(state, args, id) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    case Blocks.fetch_key_block_micro_blocks(state, id, pagination, cursor) do
      {:ok, {prev, blocks, next}} ->
        {:ok,
         %{
           prev_cursor: Helpers.cursor_val(prev),
           next_cursor: Helpers.cursor_val(next),
           data: blocks |> Enum.map(&Helpers.normalize_map/1)
         }}

      {:error, err} ->
        {:error, ErrInput.message(err)}
    end
  end

  def micro_block(_p, %{hash: hash}, %{context: %{state: state}}) do
    case Blocks.fetch_micro_block(state, hash) do
      {:ok, block} -> {:ok, block |> Helpers.normalize_map()}
      {:error, err} -> {:error, ErrInput.message(err)}
    end
  end

  defp key_block_by_id(state, id) do
    case Blocks.fetch_key_block(state, id) do
      {:ok, block} -> {:ok, block |> Helpers.normalize_map()}
      {:error, err} -> {:error, ErrInput.message(err)}
    end
  end
end

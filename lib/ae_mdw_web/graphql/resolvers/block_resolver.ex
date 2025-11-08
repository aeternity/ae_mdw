defmodule AeMdwWeb.GraphQL.Resolvers.BlockResolver do
  alias AeMdw.Blocks
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def key_blocks(_p, args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)

    Blocks.fetch_key_blocks(state, direction, scope, cursor, limit)
    |> Helpers.make_page()
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

    Blocks.fetch_key_block_micro_blocks(state, id, pagination, cursor)
    |> Helpers.make_page()
  end

  def micro_block(_p, %{hash: hash}, %{context: %{state: state}}) do
    Blocks.fetch_micro_block(state, hash) |> Helpers.make_single()
  end

  defp key_block_by_id(state, id) do
    Blocks.fetch_key_block(state, id) |> Helpers.make_single()
  end
end

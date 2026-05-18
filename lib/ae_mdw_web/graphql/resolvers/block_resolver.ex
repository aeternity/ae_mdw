defmodule AeMdwWeb.GraphQL.Resolvers.BlockResolver do
  alias AeMdw.Blocks
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  @spec key_blocks(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def key_blocks(_parent, args, %{context: %{state: state}}) do
    %{direction: direction, limit: limit, cursor: cursor, scope: scope} =
      Helpers.pagination_args_all_with_scope(args)

    case Blocks.fetch_key_blocks(state, direction, scope, cursor, limit) do
      {:ok, _} = ok -> Helpers.make_page(ok)
      {:error, _} -> {:error, "key_blocks_error"}
    end
  end

  def key_blocks(_parent, _args, _resolution), do: {:error, "partial_state_unavailable"}

  @spec key_block(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def key_block(_parent, %{height: height}, %{context: %{state: state}}) do
    key_block_by_id(state, "#{height}")
  end

  def key_block(_parent, %{hash: hash}, %{context: %{state: state}}) do
    key_block_by_id(state, hash)
  end

  def key_block(_parent, _args, _resolution), do: {:error, "partial_state_unavailable"}

  @spec key_block_by_id(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def key_block_by_id(_parent, %{id: id}, %{context: %{state: state}}) do
    case Blocks.fetch_key_block(state, id) do
      {:ok, _} = ok -> Helpers.make_single(ok)
      {:error, _} -> {:error, "key_block_error"}
    end
  end

  def key_block_by_id(_parent, _args, _resolution), do: {:error, "partial_state_unavailable"}

  @spec micro_blocks(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def micro_blocks(_parent, %{height: height} = args, %{context: %{state: state}}) do
    micro_blocks_by_id(state, args, "#{height}")
  end

  def micro_blocks(_parent, %{hash: hash} = args, %{context: %{state: state}}) do
    micro_blocks_by_id(state, args, hash)
  end

  def micro_blocks(_parent, _args, _resolution), do: {:error, "partial_state_unavailable"}

  @spec micro_block(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def micro_block(_parent, %{hash: hash}, %{context: %{state: state}}) do
    case Blocks.fetch_micro_block(state, hash) do
      {:ok, _} = ok -> Helpers.make_single(ok)
      {:error, _} -> {:error, "micro_block_error"}
    end
  end

  def micro_block(_parent, _args, _resolution), do: {:error, "partial_state_unavailable"}

  @spec key_block_micro_blocks(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def key_block_micro_blocks(_parent, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    case Blocks.fetch_key_block_micro_blocks(state, id, pagination, cursor) do
      {:ok, _} = ok -> Helpers.make_page(ok)
      {:error, _} -> {:error, "key_block_micro_blocks_error"}
    end
  end

  def key_block_micro_blocks(_parent, _args, _resolution),
    do: {:error, "partial_state_unavailable"}

  defp micro_blocks_by_id(state, args, id) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    case Blocks.fetch_key_block_micro_blocks(state, id, pagination, cursor) do
      {:ok, _} = ok -> Helpers.make_page(ok)
      {:error, _} -> {:error, "key_block_micro_blocks_error"}
    end
  end

  defp key_block_by_id(state, id) do
    Blocks.fetch_key_block(state, id) |> Helpers.make_single()
  end
end

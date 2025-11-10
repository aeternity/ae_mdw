defmodule AeMdwWeb.GraphQL.Resolvers.TransactionResolver do
  alias AeMdw.Txs
  alias AeMdw.Validate
  alias AeMdwWeb.GraphQL.Resolvers.Helpers
  alias AeMdw.Db.NodeStore
  alias AeMdw.Db.State

  def transaction(_p, %{hash: hash}, %{context: %{state: state}}) do
    with {:ok, tx_hash} <- Validate.id(hash) do
      Txs.fetch(state, tx_hash, add_spendtx_details?: true, render_v3?: true)
      |> Helpers.make_single()
    else
      {:error, err} -> {:error, Helpers.format_err(err)}
    end
  end

  def transactions(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query = %{}

    query = Helpers.maybe_put(query, :types, build_type_set(args))
    query = Helpers.maybe_put(query, "account", Map.get(args, :account))
    query = Helpers.maybe_put(query, "contract", Map.get(args, :contract))
    query = Helpers.maybe_put(query, "channel", Map.get(args, :channel))
    query = Helpers.maybe_put(query, "oracle", Map.get(args, :oracle))
    query = Helpers.maybe_put(query, "sender_id", Map.get(args, :sender_id))
    query = Helpers.maybe_put(query, "recipient_id", Map.get(args, :recipient_id))
    query = Helpers.maybe_put(query, "entrypoint", Map.get(args, :entrypoint))

    opts = [render_v3?: true, add_spendtx_details?: Map.has_key?(args, :account)]

    Txs.fetch_txs(state, pagination, scope, query, cursor, opts) |> Helpers.make_page()
  end

  def pending_transactions(_p, args, _res) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    try do
      NodeStore.new()
      |> State.new()
      |> Txs.fetch_pending_txs(pagination, nil, cursor)
      |> Helpers.make_page()
    rescue
      _ -> {:error, "pending_transactions_error"}
    end
  end

  def pending_transactions_count(_p, _args, _res) do
    try do
      {:ok, AeMdw.Node.Db.pending_txs_count()}
    rescue
      _ -> {:error, "pending_transactions_count_error"}
    end
  end

  def transactions_count(_p, args, %{context: %{state: state}}) do
    scope = Helpers.make_scope(args)

    query = %{}

    query = Helpers.maybe_put(query, "id", Map.get(args, :id))
    query = Helpers.maybe_put(query, "type", Map.get(args, :type))
    query = Helpers.maybe_put(query, "type_group", Map.get(args, :type_group))

    Txs.count(state, scope, query) |> Helpers.make_single()
  end

  def micro_block_transactions(_p, %{hash: hash} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    query = %{}

    query = Helpers.maybe_put(query, :types, build_type_set(args))

    Txs.fetch_micro_block_txs(state, hash, query, pagination, cursor, render_v3?: true)
    |> Helpers.make_page()
  end

  def account_transactions_count(_p, %{id: id} = args, %{context: %{state: state}}) do
    with {:ok, pubkey} <- Validate.id(id) do
      result =
        cond do
          Map.has_key?(args, :type_group) ->
            with {:ok, tx_type_group} <- Validate.tx_group(args.type_group) do
              {:ok, Txs.count_id_type_group(state, pubkey, tx_type_group)}
            end

          Map.has_key?(args, :type) ->
            with {:ok, tx_type} <- Validate.tx_type(args.type) do
              {:ok, Txs.count_id_type(state, pubkey, tx_type)}
            end

          true ->
            {:ok, Txs.id_counts(state, pubkey)}
        end

      result |> Helpers.make_single()
    else
      {:error, err} -> {:error, Helpers.format_err(err)}
    end
  end

  defp build_type_set(args) do
    types = Map.get(args, :type, [])
    type_groups = Map.get(args, :type_group, [])

    validated_types =
      types
      |> Enum.flat_map(fn type ->
        case Validate.tx_type(to_string(type)) do
          {:ok, valid} -> [valid]
          {:error, _} -> []
        end
      end)

    validated_type_groups =
      type_groups
      |> Enum.flat_map(fn group ->
        case Validate.tx_group(to_string(group)) do
          {:ok, valid} -> [valid]
          {:error, _} -> []
        end
      end)

    all_types = validated_types ++ validated_type_groups

    if all_types == [] do
      nil
    else
      MapSet.new(all_types)
    end
  end
end

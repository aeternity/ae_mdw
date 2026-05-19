defmodule AeMdwWeb.GraphQL.Resolvers.TransactionResolver do
  @moduledoc false

  alias AeMdw.Txs
  alias AeMdw.Validate
  alias AeMdwWeb.GraphQL.Resolvers.Helpers
  alias AeMdw.Db.NodeStore
  alias AeMdw.Db.State

  @spec transaction(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def transaction(parent, %{id: id} = args, ctx) do
    transaction(parent, Map.delete(Map.put(args, :hash, id), :id), ctx)
  end

  def transaction(_parent, %{hash: hash}, %{context: %{state: state}}) do
    case Validate.id(hash) do
      {:ok, tx_hash} ->
        case Txs.fetch(state, tx_hash, add_spendtx_details?: true, render_v3?: true) do
          {:ok, _} = ok -> Helpers.make_single(ok)
          {:error, _} -> {:error, "transaction_error"}
        end

      {:error, _} ->
        {:error, "transaction_error"}
    end
  end

  def transaction(_parent, _args, _resolution), do: {:error, "partial_state_unavailable"}

  @spec transactions(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def transactions(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query =
      Helpers.build_query(args, [
        :account,
        :contract,
        :channel,
        :oracle,
        :sender_id,
        :recipient_id,
        :entrypoint
      ])

    case build_type_set(args) do
      {:ok, types} ->
        query = Helpers.maybe_put(query, :types, types)

        opts = [render_v3?: true, add_spendtx_details?: Map.has_key?(args, :account)]

        Helpers.make_page(Txs.fetch_txs(state, pagination, scope, query, cursor, opts))

      {:error, err} ->
        {:error, Helpers.format_err(err)}
    end
  end

  @spec pending_transactions(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def pending_transactions(_parent, args, _resolution) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)

    try do
      Helpers.make_page(
        Txs.fetch_pending_txs(State.new(NodeStore.new()), pagination, nil, cursor)
      )
    rescue
      err ->
        require Logger
        Logger.error("pending_transactions failed: #{Exception.message(err)}")
        {:error, "pending_transactions_error"}
    end
  end

  @spec pending_transactions_count(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def pending_transactions_count(_parent, _args, _resolution) do
    try do
      {:ok, AeMdw.Node.Db.pending_txs_count()}
    rescue
      err ->
        require Logger
        Logger.error("pending_transactions_count failed: #{Exception.message(err)}")
        {:error, "pending_transactions_count_error"}
    end
  end

  @spec transactions_count(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def transactions_count(_parent, args, %{context: %{state: state}}) do
    scope = Helpers.make_scope(args)
    query = Helpers.build_query(args, [:id, :type, :type_group])
    Helpers.make_single(Txs.count(state, scope, query))
  end

  @spec micro_block_transactions(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def micro_block_transactions(_parent, %{hash: hash} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor} = Helpers.pagination_args(args)
    query = %{}

    case build_type_set(args) do
      {:ok, types} ->
        query = Helpers.maybe_put(query, :types, types)

        case Txs.fetch_micro_block_txs(state, hash, query, pagination, cursor, render_v3?: true) do
          {:ok, _} = ok -> Helpers.make_page(ok)
          {:error, _} -> {:error, "micro_block_transactions_error"}
        end

      {:error, err} ->
        {:error, Helpers.format_err(err)}
    end
  end

  def micro_block_transactions(_parent, _args, _resolution),
    do: {:error, "partial_state_unavailable"}

  @spec account_transactions_count(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def account_transactions_count(_parent, %{id: id} = args, %{context: %{state: state}}) do
    case Validate.id(id) do
      {:ok, pubkey} ->
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

      {:error, err} ->
        {:error, Helpers.format_err(err)}
    end
  end

  defp build_type_set(args) do
    types = Map.get(args, :type, [])
    type_groups = Map.get(args, :type_group, [])

    with {:ok, validated_types} <- validate_filter_values(types, &Validate.tx_type/1),
         {:ok, validated_type_groups} <- validate_filter_values(type_groups, &Validate.tx_group/1) do
      all_types = validated_types ++ validated_type_groups

      {:ok,
       if all_types == [] do
         nil
       else
         MapSet.new(all_types)
       end}
    end
  end

  defp validate_filter_values(values, validator) do
    values
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, acc} ->
      case validator.(to_string(value)) do
        {:ok, valid} -> {:cont, {:ok, [valid | acc]}}
        {:error, err} -> {:halt, {:error, err}}
      end
    end)
    |> case do
      {:ok, validated_values} -> {:ok, Enum.reverse(validated_values)}
      {:error, err} -> {:error, err}
    end
  end
end

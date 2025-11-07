defmodule AeMdwWeb.GraphQL.Resolvers.Aex141Resolver do
  alias AeMdw.AexnTokens
  alias AeMdw.AexnTransfers
  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Stats
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  require Model

  def aex141_count(_p, _args, %{context: %{state: state}}) do
    count =
      case State.get(state, Model.Stat, Stats.aexn_count_key(:aex141)) do
        {:ok, Model.stat(payload: count)} -> count
        :not_found -> 0
      end

    {:ok, count}
  end

  def aex141_contracts(_p, args, %{context: %{state: state}}) do
    order_by = Map.get(args, :order_by)
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}
    query = Helpers.maybe_put(query, "prefix", Map.get(args, :prefix))
    query = Helpers.maybe_put(query, "exact", Map.get(args, :exact))

    case AexnTokens.fetch_contracts(state, pagination, :aex141, query, order_by, cursor, true) do
      {:ok, {prev, items, next}} ->
        {:ok,
         %{
           prev_cursor: Helpers.cursor_val(prev),
           next_cursor: Helpers.cursor_val(next),
           data: items
         }}

      {:error, err} ->
        {:error, ErrInput.message(err)}
    end
  end

  def aex141_contract(_p, %{id: id}, %{context: %{state: state}}) do
    case AexnTokens.fetch_contract(state, :aex141, id, true) do
      {:ok, contract} ->
        {:ok, contract}

      {:error, err} ->
        {:error, ErrInput.message(err)}
    end
  end

  def aex141_transfers(_p, args, %{context: %{state: %State{} = state}}) do
    sender = Map.get(args, :sender)
    recipient = Map.get(args, :recipient)
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query = %{}
    query = Helpers.maybe_put(query, "from", sender)
    query = Helpers.maybe_put(query, "to", recipient)

    case AexnTransfers.fetch_aex141_transfers(state, pagination, cursor, query) do
      {:ok, {prev, items, next}} ->
        {:ok,
         %{
           prev_cursor: Helpers.cursor_val(prev),
           next_cursor: Helpers.cursor_val(next),
           data: Enum.map(items, &AeMdwWeb.AexnView.pair_transfer_to_map(state, &1))
         }}

      {:error, err} ->
        {:error, ErrInput.message(err)}
    end
  end

  # @spec aex141_contract_transfers(any, map(), Absinthe.Resolution.t()) ::
  #        {:ok, map()} | {:error, String.t()}
  # def aex141_contract_transfers(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
  #  limit = clamp_limit(Map.get(args, :limit, 50))
  #  cursor = Map.get(args, :cursor)
  #  sender = Map.get(args, :sender)
  #  recipient = Map.get(args, :recipient)
  #  pagination = {:backward, false, limit, not is_nil(cursor)}

  #  filter =
  #    cond do
  #      sender && recipient -> {:error, {ErrInput.Query, "set either a recipient or a sender"}}
  #      sender -> {:from, sender}
  #      recipient -> {:to, recipient}
  #      true -> {:from, nil}
  #    end

  #  with {:ok, {_k, _a}} <- validate_filter(filter),
  #       {:ok, contract_pk} <- AeMdw.Validate.id(id, [:contract_pubkey]) do
  #    case AexnTransfers.fetch_contract_transfers(
  #           state,
  #           contract_pk,
  #           normalize_filter(filter),
  #           pagination,
  #           cursor
  #         ) do
  #      {:ok, {prev, keys, next}} ->
  #        data =
  #          Enum.map(
  #            keys,
  #            &AeMdwWeb.AexnView.contract_transfer_to_map(
  #              state,
  #              :aex141,
  #              elem(filter, 0),
  #              &1,
  #              true
  #            )
  #          )

  #        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: data}}

  #      {:error, %ErrInput.Cursor{}} ->
  #        {:error, "invalid_cursor"}

  #      {:error, %ErrInput.NotFound{}} ->
  #        {:error, "contract_not_found"}

  #      {:error, _} ->
  #        {:error, "aex141_contract_transfers_error"}
  #    end
  #  else
  #    {:error, %ErrInput.Query{}} -> {:error, "invalid_filter"}
  #    {:error, _} -> {:error, "aex141_contract_transfers_error"}
  #  end
  # end

  # def aex141_contract_transfers(_, _args, _), do: {:error, "partial_state_unavailable"}

  ## -------------- Contract owners/tokens/templates --------------
  # @spec aex141_contract_tokens(any, map(), Absinthe.Resolution.t()) ::
  #        {:ok, map()} | {:error, String.t()}
  # def aex141_contract_tokens(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
  #  limit = clamp_limit(Map.get(args, :limit, 50))
  #  cursor = Map.get(args, :cursor)
  #  pagination = {:backward, false, limit, not is_nil(cursor)}

  #  with {:ok, contract_pk} <- AeMdw.Validate.id(id, [:contract_pubkey]),
  #       {:ok, {prev, items, next}} <-
  #         Aex141.fetch_collection_owners(state, contract_pk, cursor, pagination) do
  #    {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: items}}
  #  else
  #    {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
  #    {:error, %ErrInput.NotFound{}} -> {:error, "contract_not_found"}
  #    {:error, _} -> {:error, "aex141_contract_tokens_error"}
  #  end
  # end

  # def aex141_contract_tokens(_, _args, _), do: {:error, "partial_state_unavailable"}

  # @spec aex141_contract_templates(any, map(), Absinthe.Resolution.t()) ::
  #        {:ok, map()} | {:error, String.t()}
  # def aex141_contract_templates(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
  #  limit = clamp_limit(Map.get(args, :limit, 50))
  #  cursor = Map.get(args, :cursor)
  #  pagination = {:backward, false, limit, not is_nil(cursor)}

  #  with {:ok, contract_pk} <- AeMdw.Validate.id(id, [:contract_pubkey]),
  #       {:ok, {prev, items, next}} <-
  #         Aex141.fetch_templates(state, contract_pk, cursor, pagination) do
  #    {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: items}}
  #  else
  #    {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
  #    {:error, _} -> {:error, "aex141_contract_templates_error"}
  #  end
  # end

  # def aex141_contract_templates(_, _args, _), do: {:error, "partial_state_unavailable"}

  # @spec aex141_template_tokens(any, map(), Absinthe.Resolution.t()) ::
  #        {:ok, map()} | {:error, String.t()}
  # def aex141_template_tokens(_p, %{id: id, template_id: template_id} = args, %{
  #      context: %{state: %State{} = state}
  #    }) do
  #  limit = clamp_limit(Map.get(args, :limit, 50))
  #  cursor = Map.get(args, :cursor)
  #  pagination = {:backward, false, limit, not is_nil(cursor)}

  #  with {:ok, contract_pk} <- AeMdw.Validate.id(id, [:contract_pubkey]),
  #       {template_id_int, ""} <- Integer.parse(to_string(template_id)),
  #       {:ok, {prev, items, next}} <-
  #         Aex141.fetch_template_tokens(state, contract_pk, template_id_int, cursor, pagination) do
  #    {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: items}}
  #  else
  #    {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
  #    _ -> {:error, "aex141_template_tokens_error"}
  #  end
  # end

  # def aex141_template_tokens(_, _args, _), do: {:error, "partial_state_unavailable"}

  ## -------------- Token detail --------------
  # @spec aex141_token_detail(any, map(), Absinthe.Resolution.t()) ::
  #        {:ok, map()} | {:error, String.t()}
  # def aex141_token_detail(_p, %{contract_id: cid, token_id: tid}, %{
  #      context: %{state: %State{} = state}
  #    }) do
  #  case Aex141.fetch_nft(state, cid, to_string(tid), v3?: true) do
  #    {:ok, %{contract_id: c, token_id: t, owner: owner, metadata: md}} ->
  #      {:ok, %{contract_id: c, token_id: t, owner_id: owner, metadata: md}}

  #    {:error, %ErrInput.NotFound{}} ->
  #      {:error, "not_found"}

  #    {:error, _} ->
  #      {:error, "aex141_token_detail_error"}
  #  end
  # end

  # def aex141_token_detail(_, _args, _), do: {:error, "partial_state_unavailable"}

  ## -------------- Helpers --------------
  # defp clamp_limit(l) when is_integer(l) and l > @max_limit, do: @max_limit
  # defp clamp_limit(l) when is_integer(l) and l > 0, do: l
  # defp clamp_limit(_), do: 20

  # defp maybe_put(map, _k, nil), do: map
  # defp maybe_put(map, k, v), do: Map.put(map, k, v)

  # defp cursor_val(nil), do: nil
  # defp cursor_val({val, _rev}), do: val

  # defp validate_filter({:error, _} = err), do: err

  # defp validate_filter({kind, acct}) when kind in [:from, :to] do
  #  case AeMdw.Validate.id(acct, [:account_pubkey]) do
  #    {:ok, _} -> {:ok, {kind, acct}}
  #    {:error, reason} -> {:error, reason}
  #  end
  # end

  # defp validate_filter({:from, nil}), do: {:ok, {:from, nil}}

  # defp normalize_filter({:from, nil}), do: {:from, nil}

  # defp normalize_filter({kind, acct}) do
  #  {:ok, pk} = AeMdw.Validate.id(acct, [:account_pubkey])
  #  {kind, pk}
  # end
end

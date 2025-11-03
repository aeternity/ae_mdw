defmodule AeMdwWeb.GraphQL.Resolvers.Aex9Resolver do
  @moduledoc """
  AEX9 resolvers: tokens, balances, balance history, and transfers.
  """
  alias AeMdw.{Aex9, AexnTokens, AexnTransfers}
  alias AeMdw.Db.{State, Model}
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Stats

  @max_limit 100

  # ---------------- Count ----------------
  @spec aex9_count(any, map(), Absinthe.Resolution.t()) :: {:ok, integer()} | {:error, String.t()}
  def aex9_count(_p, _args, %{context: %{state: %State{} = state}}) do
    case State.get(state, Model.Stat, Stats.aexn_count_key(:aex9)) do
      {:ok, {:stat, _key, count}} -> {:ok, count}
      :not_found -> {:ok, 0}
    end
  end
  def aex9_count(_, _args, _), do: {:error, "partial_state_unavailable"}

  # ---------------- Tokens ----------------
  @spec aex9_contract(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def aex9_contract(_p, %{id: id}, %{context: %{state: %State{} = state}}) do
    case AexnTokens.fetch_contract(state, :aex9, id, true) do
      {:ok, contract} -> {:ok, contract}
      {:error, %ErrInput.NotFound{}} -> {:error, "contract_not_found"}
      {:error, _} -> {:error, "aex9_contract_error"}
    end
  end
  def aex9_contract(_, _args, _), do: {:error, "partial_state_unavailable"}

  @spec aex9_contracts(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def aex9_contracts(_p, args, %{context: %{state: %State{} = state}}) do
    limit = clamp_limit(Map.get(args, :limit, 20))
    cursor = Map.get(args, :cursor)
    by = Map.get(args, :by, "creation")
    order_by = case by do
      "name" -> :name
      "symbol" -> :symbol
      _ -> :creation
    end

    query = %{}
    query = maybe_put(query, "prefix", Map.get(args, :prefix))
    query = maybe_put(query, "exact", Map.get(args, :exact))
    pagination = {:backward, false, limit, not is_nil(cursor)}

    case AexnTokens.fetch_contracts(state, pagination, :aex9, query, order_by, cursor, true) do
      {:ok, {prev, items, next}} ->
        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: items}}

      {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
      {:error, %ErrInput.Query{}} -> {:error, "invalid_filter"}
      {:error, _} -> {:error, "aex9_contracts_error"}
    end
  end
  def aex9_contracts(_, _args, _), do: {:error, "partial_state_unavailable"}

  # ---------------- Contract balances ----------------
  @spec aex9_contract_balances(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def aex9_contract_balances(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    limit = clamp_limit(Map.get(args, :limit, 50))
    cursor = Map.get(args, :cursor)
    order_by = case Map.get(args, :order_by, :pubkey) do
      :amount -> :amount
      _ -> :pubkey
    end

    # optional block_hash filter
    query = case Map.get(args, :block_hash) do
      nil -> %{}
      bh -> %{"block_hash" => bh}
    end

    pagination = {:backward, false, limit, not is_nil(cursor)}
    case Aex9.fetch_event_balances(state, id, pagination, cursor, order_by, query) do
      {:ok, {prev, items, next}} ->
        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: items}}

      {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
      {:error, %ErrInput.Query{}} -> {:error, "invalid_filter"}
      {:error, %ErrInput.NotFound{}} -> {:error, "contract_not_found"}
      {:error, _} -> {:error, "aex9_balances_error"}
    end
  end
  def aex9_contract_balances(_, _args, _), do: {:error, "partial_state_unavailable"}

  # ---------------- Single balance ----------------
  @spec aex9_token_balance(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def aex9_token_balance(_p, %{contract_id: cid, account_id: aid} = args, %{context: %{state: %State{} = state}}) do
    hash = Map.get(args, :hash)
    with {:ok, balance} <- do_fetch_balance(state, cid, aid, hash) do
      # Normalize keys to GraphQL: contract_id/account_id
      {:ok, %{contract_id: balance.contract, account_id: balance.account, amount: balance.amount}}
    else
      {:error, %ErrInput.NotFound{}} -> {:error, "not_found"}
      {:error, %ErrInput.Query{}} -> {:error, "invalid_filter"}
      {:error, _} -> {:error, "aex9_balance_error"}
    end
  end
  def aex9_token_balance(_, _args, _), do: {:error, "partial_state_unavailable"}

  defp do_fetch_balance(_state, contract_id, account_id, hash) do
    # AexnTokenController uses Validate in Aex9.fetch_balance via AexnContracts; here we rely on Aex9 directly but it expects pks.
    case AeMdw.Validate.id(contract_id, [:contract_pubkey]) do
      {:ok, contract_pk} ->
        with {:ok, account_pk} <- AeMdw.Validate.id(account_id, [:account_pubkey]),
             {:ok, height_hash} <- validate_block_hash(hash),
             {:ok, balance} <- Aex9.fetch_balance(contract_pk, account_pk, height_hash) do
          {:ok, balance}
        end
      other -> other
    end
  end

  defp validate_block_hash(nil), do: {:ok, nil}
  defp validate_block_hash(block_id) do
    case :aeser_api_encoder.safe_decode(:block_hash, block_id) do
      {:ok, block_hash} ->
        case :aec_chain.get_block(block_hash) do
          {:ok, block} -> {:ok, {:aec_blocks.type(block), :aec_blocks.height(block), block_hash}}
          :error -> {:error, ErrInput.NotFound.exception(value: block_id)}
        end
      _ -> {:error, ErrInput.Query.exception(value: block_id)}
    end
  end

  # ---------------- Balance history ----------------
  @spec aex9_balance_history(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def aex9_balance_history(_p, %{contract_id: cid, account_id: aid} = args, %{context: %{state: %State{} = state}}) do
    limit = clamp_limit(Map.get(args, :limit, 50))
    cursor = Map.get(args, :cursor)
    from_h = Map.get(args, :from_height)
    to_h = Map.get(args, :to_height)

    range =
      cond do
        from_h && to_h -> {:gen, from_h..to_h}
        to_h && is_nil(from_h) -> {:gen, 0..to_h}
        from_h && is_nil(to_h) -> {:gen, from_h..from_h}
        true -> nil
      end

    pagination = {:backward, false, limit, not is_nil(cursor)}

    with {:ok, contract_pk} <- AeMdw.Validate.id(cid, [:contract_pubkey]),
         {:ok, account_pk} <- AeMdw.Validate.id(aid, [:account_pubkey]),
         {:ok, {prev, items, next}} <- Aex9.fetch_balance_history(state, contract_pk, account_pk, range, cursor, pagination) do
      # Normalize keys from %{contract: _, account: _}
      data = Enum.map(items, fn itm ->
        %{
          contract_id: itm.contract,
          account_id: itm.account,
          height: itm.height,
          amount: itm.amount
        }
      end)

      {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: data}}
    else
      {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
      {:error, %ErrInput.Scope{}} -> {:error, "invalid_scope"}
      {:error, _} -> {:error, "aex9_balance_history_error"}
    end
  end
  def aex9_balance_history(_, _args, _), do: {:error, "partial_state_unavailable"}

  # ---------------- Transfers ----------------
  @spec aex9_contract_transfers(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def aex9_contract_transfers(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    limit = clamp_limit(Map.get(args, :limit, 50))
    cursor = Map.get(args, :cursor)
    sender = Map.get(args, :sender)
    recipient = Map.get(args, :recipient)
    account = Map.get(args, :account)

    filter =
      cond do
        sender && recipient -> {:error, {ErrInput.Query, "set either a recipient or a sender"}}
        sender -> {:from, sender}
        recipient -> {:to, recipient}
        account -> {nil, account}
        true -> {:error, {ErrInput.Query, "sender or recipient param is required"}}
      end

    with {:ok, {_type, _acct}} <- validate_filter(filter),
         {:ok, _} <- AeMdw.Validate.id(id, [:contract_pubkey]) do
      pagination = {:backward, false, limit, not is_nil(cursor)}
      # controller uses v3? true for contract-based transfers
      case do_contract_transfers(state, id, filter, pagination, cursor) do
        {:ok, {prev, keys, next}} ->
          data = Enum.map(keys, &AeMdwWeb.AexnView.contract_transfer_to_map(state, :aex9, elem(filter, 0), &1, true))
          {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: data}}
        {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
        {:error, %ErrInput.NotFound{}} -> {:error, "contract_not_found"}
        {:error, _} -> {:error, "aex9_contract_transfers_error"}
      end
    else
      {:error, %ErrInput.Query{}} -> {:error, "invalid_filter"}
      {:error, _} -> {:error, "aex9_contract_transfers_error"}
    end
  end
  def aex9_contract_transfers(_, _args, _), do: {:error, "partial_state_unavailable"}

  @spec aex9_transfers_from(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def aex9_transfers_from(_p, %{sender: sender} = args, %{context: %{state: %State{} = state}}) do
    limit = clamp_limit(Map.get(args, :limit, 50))
    cursor = Map.get(args, :cursor)
    pagination = {:backward, false, limit, not is_nil(cursor)}

    case AexnTransfers.fetch_sender_transfers(state, :aex9, validate_id!(sender), pagination, cursor) do
      {:ok, {prev, items, next}} ->
        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: Enum.map(items, &AeMdwWeb.AexnView.sender_transfer_to_map(state, &1))}}
      {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
      {:error, _} -> {:error, "aex9_transfers_error"}
    end
  end
  def aex9_transfers_from(_, _args, _), do: {:error, "partial_state_unavailable"}

  @spec aex9_transfers_to(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def aex9_transfers_to(_p, %{recipient: recipient} = args, %{context: %{state: %State{} = state}}) do
    limit = clamp_limit(Map.get(args, :limit, 50))
    cursor = Map.get(args, :cursor)
    pagination = {:backward, false, limit, not is_nil(cursor)}

    case AexnTransfers.fetch_recipient_transfers(state, :aex9, validate_id!(recipient), pagination, cursor) do
      {:ok, {prev, items, next}} ->
        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: Enum.map(items, &AeMdwWeb.AexnView.recipient_transfer_to_map(state, &1))}}
      {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
      {:error, _} -> {:error, "aex9_transfers_error"}
    end
  end
  def aex9_transfers_to(_, _args, _), do: {:error, "partial_state_unavailable"}

  @spec aex9_transfers_pair(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def aex9_transfers_pair(_p, %{sender: s, recipient: r} = args, %{context: %{state: %State{} = state}}) do
    limit = clamp_limit(Map.get(args, :limit, 50))
    cursor = Map.get(args, :cursor)
    pagination = {:backward, false, limit, not is_nil(cursor)}

    case AexnTransfers.fetch_pair_transfers(state, :aex9, validate_id!(s), validate_id!(r), pagination, cursor) do
      {:ok, {prev, items, next}} ->
        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: Enum.map(items, &AeMdwWeb.AexnView.pair_transfer_to_map(state, &1))}}
      {:error, %ErrInput.Cursor{}} -> {:error, "invalid_cursor"}
      {:error, _} -> {:error, "aex9_transfers_error"}
    end
  end
  def aex9_transfers_pair(_, _args, _), do: {:error, "partial_state_unavailable"}

  # ---------------- Helpers ----------------
  defp do_contract_transfers(state, contract_id, {kind, acct_id}, pagination, cursor) do
    with {:ok, contract_pk} <- AeMdw.Validate.id(contract_id, [:contract_pubkey]),
         {:ok, account_pk} <- AeMdw.Validate.optional_id(acct_id, [:account_pubkey]) do
      AexnTransfers.fetch_contract_transfers(state, contract_pk, {kind, account_pk}, pagination, cursor)
    end
  end

  defp validate_filter({:error, _} = err), do: err
  defp validate_filter({kind, acct}) when kind in [:from, :to] do
    case AeMdw.Validate.id(acct, [:account_pubkey]) do
      {:ok, _} -> {:ok, {kind, acct}}
      {:error, reason} -> {:error, reason}
    end
  end
  defp validate_filter({nil, acct}) do
    case AeMdw.Validate.id(acct, [:account_pubkey]) do
      {:ok, _} -> {:ok, {nil, acct}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_id!(id) do
    case AeMdw.Validate.id(id, [:account_pubkey]) do
      {:ok, pk} -> pk
      _ -> <<0::256>>
    end
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  defp cursor_val(nil), do: nil
  defp cursor_val({val, _rev}), do: val

  defp clamp_limit(l) when is_integer(l) and l > @max_limit, do: @max_limit
  defp clamp_limit(l) when is_integer(l) and l > 0, do: l
  defp clamp_limit(_), do: 20
end

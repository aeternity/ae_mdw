defmodule AeMdwWeb.GraphQL.Resolvers.AccountResolver do
  @moduledoc """
  Account resolvers: single account lookup and simple backward pagination.
  """
  alias AeMdw.Db.{State, Model}
  alias AeMdw.Validate

  @page_limit 100

  @spec account(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def account(_parent, %{id: id}, %{context: %{state: %State{} = state}}) do
    with {:ok, account_pk} <- Validate.id(id) do
      case State.get(state, Model.AccountBalance, account_pk) do
        {:ok, acc_balance} ->
          # Record layout: {:account_balance, index, balance}
          {:account_balance, ^account_pk, balance} = acc_balance
          creation_time =
            case State.get(state, Model.AccountCreation, account_pk) do
              {:ok, {:account_creation, ^account_pk, ctime}} -> ctime
              :not_found -> nil
            end
          nonce = nil
          names_count = case State.get(state, Model.AccountNamesCount, account_pk) do
            {:ok, {:account_names_count, ^account_pk, count}} -> count
            _ -> nil
          end
          activities_count = account_activity_count(state, account_pk)
          {:ok, %{id: id, balance: balance, creation_time: creation_time, nonce: nonce, names_count: names_count, activities_count: activities_count}}
        :not_found -> {:error, "account_not_found"}
      end
    else
      {:error, _} -> {:error, "invalid_account"}
    end
  end
  def account(_, _args, _), do: {:error, "partial_state_unavailable"}

  @spec accounts(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def accounts(_parent, args, %{context: %{state: %State{} = state}}) do
    limit = args |> Map.get(:limit, 20) |> clamp_limit()
    cursor_id = Map.get(args, :cursor)

    cursor_pk = case cursor_id do
      nil -> nil
      id -> case Validate.id(id) do {:ok, pk} -> pk; _ -> nil end
    end

    {accounts, next_cursor} = collect_backward(state, cursor_pk, limit)

    data = Enum.map(accounts, fn {id_enc, balance, creation_time} ->
      %{id: id_enc, balance: balance, creation_time: creation_time}
    end)

    {:ok, %{prev_cursor: nil, next_cursor: next_cursor, data: data}}
  end
  def accounts(_, _args, _), do: {:error, "partial_state_unavailable"}

  @spec account_names(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def account_names(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    limit = args |> Map.get(:limit, 20) |> clamp_limit()
    cursor_enc = Map.get(args, :cursor)
    with {:ok, account_pk} <- Validate.id(id) do
      start_key =
        case cursor_enc do
          nil -> {account_pk, <<255::256>>}
          enc_name ->
            case Validate.id(enc_name) do
              {:ok, name_hash} -> {account_pk, name_hash}
              _ -> {account_pk, <<255::256>>}
            end
        end

      {collected, last_hash} = collect_account_names(state, account_pk, start_key, limit, [])
      data = Enum.map(collected, &name_entry(state, {account_pk, &1}))
      next_cursor = if last_hash, do: encode_name(last_hash), else: nil
      {:ok, %{prev_cursor: cursor_enc, next_cursor: next_cursor, data: data}}
    else
      _ -> {:error, "invalid_account"}
    end
  end
  def account_names(_, _args, _), do: {:error, "partial_state_unavailable"}

  defp collect_account_names(state, account_pk, {account_pk, prev_hash} = key, limit, acc) do
    if length(acc) >= limit do
      {Enum.reverse(acc), prev_hash}
    else
      case State.prev(state, Model.ActiveNameOwner, key) do
        {:ok, {^account_pk, name_hash}} ->
          collect_account_names(state, account_pk, {account_pk, name_hash}, limit, [name_hash | acc])
        _ -> {Enum.reverse(acc), nil}
      end
    end
  end
  defp collect_account_names(_state, _account_pk, _key, _limit, acc), do: {Enum.reverse(acc), nil}

  defp name_entry(state, {_account_pk, name_hash}) do
    active? = State.exists?(state, Model.ActiveName, name_hash)
    expire_h = case State.get(state, Model.ActiveNameExpiration, name_hash) do
      {:ok, {:active_name_expiration, ^name_hash, h}} -> h
      _ -> nil
    end
    %{name: encode_name(name_hash), active: active?, expire_height: expire_h}
  end

  defp encode_name(hash), do: :aeser_api_encoder.encode(:name, hash)

  @spec account_aex9_balances(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def account_aex9_balances(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    limit = args |> Map.get(:limit, 50) |> clamp_limit()
    cursor = Map.get(args, :cursor)
    with {:ok, account_pk} <- Validate.id(id) do
      # scan Aex9AccountPresence by account_pk
      start_key = case cursor do
        nil -> {account_pk, <<255::256>>}
        c when is_binary(c) -> {account_pk, decode_contract(c)}
      end
      balances_stream =
        Stream.resource(
          fn -> State.prev(state, Model.Aex9AccountPresence, start_key) end,
          fn
            {:ok, {acct, contract_pk}} when acct == account_pk ->
              amount = aex9_balance(state, contract_pk, account_pk)
              next = State.prev(state, Model.Aex9AccountPresence, {account_pk, contract_pk})
              {[%{contract_id: encode_contract(contract_pk), amount: amount}], next}
            _ -> {:halt, nil}
          end,
          fn _ -> :ok end
        )
        |> Enum.uniq_by(& &1.contract_id)
      data = Enum.take(balances_stream, limit)
      next_cursor = case List.last(data) do
        nil -> nil
        %{contract_id: cid} -> cid
      end
      {:ok, %{prev_cursor: cursor, next_cursor: next_cursor, data: data}}
    else
      _ -> {:error, "invalid_account"}
    end
  end
  def account_aex9_balances(_, _args, _), do: {:error, "partial_state_unavailable"}

  defp aex9_balance(_state, contract_pk, account_pk) do
    try do
      {amount, _height_hash} = AeMdw.Node.Db.aex9_balance(contract_pk, account_pk, false)
      amount
    rescue
      _ -> nil
    end
  end
  defp encode_contract(pk), do: :aeser_api_encoder.encode(:contract_pubkey, pk)
  defp decode_contract(id) do
    case Validate.id(id) do
      {:ok, pk} -> pk
      _ -> <<0::256>>
    end
  end

  defp collect_backward(state, cursor_pk, limit) do
    start_pk =
      case cursor_pk do
        nil -> case State.prev(state, Model.AccountBalance, nil) do {:ok, pk} -> pk; :none -> nil end
        pk -> case State.prev(state, Model.AccountBalance, pk) do {:ok, prev_pk} -> prev_pk; :none -> nil end
      end

    do_collect(state, start_pk, limit, [])
  end

  defp do_collect(_state, nil, _limit, acc), do: {Enum.reverse(acc), nil}
  defp do_collect(_state, pk, limit, acc) when length(acc) >= limit do
    next_cursor = encode_account(pk)
    {Enum.reverse(acc), next_cursor}
  end
  defp do_collect(state, pk, limit, acc) do
  acc_balance = State.fetch!(state, Model.AccountBalance, pk)
  {:account_balance, account_pk, balance} = acc_balance
    creation_time = case State.get(state, Model.AccountCreation, account_pk) do
      {:ok, {:account_creation, ^account_pk, ctime}} -> ctime
      :not_found -> nil
    end
    encoded = encode_account(account_pk)
    next_key = case State.prev(state, Model.AccountBalance, account_pk) do {:ok, prev_pk} -> prev_pk; :none -> nil end
    do_collect(state, next_key, limit, [{encoded, balance, creation_time} | acc])
  end

  defp encode_account(pk), do: :aeser_api_encoder.encode(:account_pubkey, pk)

  defp clamp_limit(l) when is_integer(l) and l > @page_limit, do: @page_limit
  defp clamp_limit(l) when is_integer(l) and l > 0, do: l
  defp clamp_limit(_), do: 20

  # Counts activity entries for a given account (could be optimized with aggregated stats later)
  defp account_activity_count(state, account_pk) do
    # naive counting: traverse successive AccountActivity entries for this pubkey
    do_count = fn do_count, key, acc ->
      case State.next(state, Model.AccountActivity, key) do
        {:ok, {^account_pk, t}} -> do_count.(do_count, {account_pk, t}, acc + 1)
        _ -> acc
      end
    end
    do_count.(do_count, {account_pk, -1}, 0)
  rescue
    _ -> nil
  end
end

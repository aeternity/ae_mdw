defmodule AeMdw.Sync.WealthRank do
  @moduledoc """
  Wallet balance ranking.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model
  @table :wealth_rank

  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @typep balances :: [{pubkey(), integer()}]
  @opaque key :: {integer, pubkey()}

  @spec init() :: :ok
  def init do
    @table = :ets.new(@table, [:named_table, :set, :public])
    :ok
  end

  @spec prune_balance_ranking(State.t()) :: {[key()], State.t()}
  def prune_balance_ranking(state) do
    keys =
      state
      |> balance_accounts()
      |> Enum.reduce(%{}, fn {amount, pubkey}, acc -> Map.put_new(acc, pubkey, amount) end)
      |> Enum.map(fn {pubkey, amount} -> {amount, pubkey} end)
      |> Enum.sort_by(fn {amount, _pubkey} -> amount end, :desc)

    top_keys = Enum.take(keys, rank_size_config())

    cleared_state = Enum.reduce(keys, state, &State.delete(&2, Model.BalanceAccount, &1))

    :ets.delete_all_objects(@table)

    {top_keys,
     Enum.reduce(top_keys, cleared_state, fn {amount, pubkey}, state ->
       insert(state, pubkey, amount)
     end)}
  end

  @spec rank_size_config :: integer()
  def rank_size_config do
    with nil <- :persistent_term.get({__MODULE__, :rank_size}, nil) do
      rank_size = Application.fetch_env!(:ae_mdw, :wealth_rank_size)
      :persistent_term.put({__MODULE__, :rank_size}, rank_size)
      rank_size
    end
  end

  @spec update_balances(State.t(), balances()) :: :ok
  def update_balances(state, balances) do
    Enum.reduce(balances, state, fn {account_pk, balance}, state_acc ->
      account_pk
      |> get_balance()
      |> case do
        old_balance when old_balance != nil ->
          State.delete(state_acc, Model.BalanceAccount, {old_balance, account_pk})

        _ ->
          state_acc
      end
      |> insert(account_pk, balance)
    end)

    State.commit(state, [])
  end

  defp insert(state, pubkey, balance) do
    :ets.insert(@table, {pubkey, balance})
    record = Model.balance_account(index: {balance, pubkey})
    State.put(state, Model.BalanceAccount, record)
  end

  defp get_balance(pubkey) do
    case :ets.lookup(@table, pubkey) do
      [{^pubkey, balance}] -> balance
      [] -> nil
    end
  end

  defp balance_accounts(state) do
    state
    |> State.prev(Model.BalanceAccount, {nil, nil})
    |> Stream.unfold(fn
      :none -> nil
      {:ok, key} -> {key, State.prev(state, Model.BalanceAccount, key)}
    end)
    |> Enum.to_list()
  end
end

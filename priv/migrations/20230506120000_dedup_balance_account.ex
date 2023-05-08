defmodule AeMdw.Migrations.DedupBalanceAccount do
  @moduledoc """
  Deduplicates balance accounts.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Sync.AsyncTasks.WealthRank
  alias AeMdw.Sync.Transaction

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    all_keys =
      state
      |> Collection.stream(Model.BalanceAccount, :forward)
      |> Enum.to_list()

    clear_mutation = DeleteKeysMutation.new(%{Model.BalanceAccount => all_keys})

    state
    |> Collection.stream(Model.Block, :forward, nil, {1, -1})
    |> Stream.filter(fn {kb, mbi} ->
      if mbi != -1, do: IO.puts("height #{kb} mbi #{mbi}")

      mbi == -1
    end)
    |> Stream.map(&State.fetch!(state, Model.Block, &1))
    |> Stream.flat_map(&AeMdw.Node.Db.get_micro_blocks(Model.block(&1, :hash)))
    |> Stream.map(&micro_block_balances/1)
    |> Stream.with_index()
    |> Enum.each(fn {balances, index} ->
      _res =
        if rem(index, 1000) == 0 do
          WealthRank.prune_balance_ranking(AsyncStore.instance())
        end

      WealthRank.update_balances(balances)
    end)

    {top_keys, _store} = WealthRank.prune_balance_ranking(AsyncStore.instance())

    write_mutations =
      Enum.map(
        top_keys,
        &WriteMutation.new(Model.BalanceAccount, Model.balance_account(index: &1))
      )

    _new_state = State.commit(state, [clear_mutation | write_mutations])

    {:ok, length(top_keys) + 1}
  end

  defp micro_block_balances(micro_block) do
    {:ok, mb_hash} = :aec_headers.hash_header(:aec_blocks.to_micro_header(micro_block))

    with {:value, trees} <- :aec_db.find_block_state_partial(mb_hash, true, [:accounts]),
         accounts_tree <- :aec_trees.accounts(trees),
         account_set <- micro_block_accounts(micro_block) do
      get_balances(accounts_tree, account_set)
    end
  end

  defp get_balances(accounts_tree, account_set) do
    account_set
    |> MapSet.to_list()
    |> Enum.flat_map(fn pubkey ->
      case :aec_accounts_trees.lookup(pubkey, accounts_tree) do
        {:value, account} -> [{pubkey, :aec_accounts.balance(account)}]
        :none -> []
      end
    end)
  end

  defp micro_block_accounts(micro_block) do
    pubkeys =
      micro_block
      |> :aec_blocks.txs()
      |> Enum.flat_map(fn signed_tx ->
        signed_tx
        |> Transaction.get_ids_from_tx()
        |> Enum.flat_map(fn
          {:id, :account, pubkey} -> [pubkey]
          _other -> []
        end)
      end)

    Enum.reduce(pubkeys, MapSet.new(), &MapSet.put(&2, &1))
  end
end

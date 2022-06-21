defmodule AeMdw.Sync.AsyncTasks.DeriveAex9Presence do
  @moduledoc """
  Async work to derive AEX9 presence from balance dry-running
  from a create contract.
  """
  @behaviour AeMdw.Sync.AsyncTasks.Work

  alias AeMdw.Node.Db, as: DBN

  alias AeMdw.Db.DeriveAex9PresenceMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.State
  alias AeMdw.Log

  require Model
  require Logger

  @microsecs 1_000_000

  @spec process(args :: list()) :: :ok
  def process([contract_pk, _kbi, _mbi, _create_txi] = args) do
    Log.info("[:derive_aex9_presence] #{inspect(contract_pk)} ...")

    {time_delta, mutations} = :timer.tc(fn -> mutations(args) end)

    Log.info("[:derive_aex9_presence] #{inspect(contract_pk)} after #{time_delta / @microsecs}s")

    State.commit(State.new(), mutations)

    :ok
  end

  @spec mutations(args :: list()) :: [Mutation.t()]
  def mutations([contract_pk, kbi, mbi, create_txi]) do
    next_kb_hash = DBN.get_key_block_hash(kbi + 1)
    next_hash = DBN.get_next_hash(next_kb_hash, mbi)

    {balances, _last_block_tuple} = DBN.aex9_balances(contract_pk, {nil, kbi, next_hash})

    if map_size(balances) == 0 do
      m_empty_balance = Model.aex9_balance(index: {contract_pk, <<>>})

      [
        WriteMutation.new(Model.Aex9Balance, m_empty_balance)
      ]
    else
      balances =
        Enum.map(balances, fn {{:address, account_pk}, amount} ->
          {account_pk, amount}
        end)

      [
        DeriveAex9PresenceMutation.new(contract_pk, {kbi, mbi}, create_txi, balances)
      ]
    end
  end
end

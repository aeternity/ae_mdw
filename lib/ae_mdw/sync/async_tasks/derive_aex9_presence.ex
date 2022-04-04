defmodule AeMdw.Sync.AsyncTasks.DeriveAex9Presence do
  @moduledoc """
  Async work to derive AEX9 presence from balance dry-running
  from a create contract.
  """
  @behaviour AeMdw.Sync.AsyncTasks.Work

  alias AeMdw.Node.Db, as: DBN

  alias AeMdw.Database
  alias AeMdw.Db.DeriveAex9PresenceMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Log

  require Model
  require Logger

  @microsecs 1_000_000

  @spec process(args :: list()) :: :ok
  def process([contract_pk, kbi, mbi, create_txi]) do
    Log.info("[:derive_aex9_presence] #{inspect(contract_pk)} ...")

    {time_delta, {balances, _last_block_tuple}} =
      :timer.tc(fn ->
        Model.block(hash: next_kb_hash) = Database.fetch!(Model.Block, {kbi + 1, -1})
        next_hash = DBN.get_next_hash(next_kb_hash, mbi)

        DBN.aex9_balances(contract_pk, {nil, kbi, next_hash})
      end)

    Log.info("[:derive_aex9_presence] #{inspect(contract_pk)} after #{time_delta / @microsecs}s")

    if map_size(balances) == 0 do
      m_empty_balance = Model.aex9_balance(index: {contract_pk, <<>>})
      Database.dirty_write(Model.Aex9Balance, m_empty_balance)
    else
      balances =
        Enum.map(balances, fn {{:address, account_pk}, amount} ->
          {account_pk, amount}
        end)

      mutation = DeriveAex9PresenceMutation.new(contract_pk, create_txi, balances)
      state = State.new()

      State.commit(state, [mutation])
    end

    :ok
  end
end

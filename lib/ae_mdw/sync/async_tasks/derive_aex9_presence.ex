defmodule AeMdw.Sync.AsyncTasks.DeriveAex9Presence do
  @moduledoc """
  Async work to derive AEX9 presence from balance dry-running
  from a create contract.
  """
  @behaviour AeMdw.Sync.AsyncTasks.Work

  alias AeMdw.Node.Db, as: DBN

  alias AeMdw.Database
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.Model
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
      Enum.each(balances, fn {{:address, account_pk}, amount} ->
        DBContract.aex9_write_presence(contract_pk, create_txi, account_pk)

        m_balance =
          Model.aex9_balance(
            index: {contract_pk, account_pk},
            block_index: {kbi, mbi},
            amount: amount
          )

        Database.dirty_write(Model.Aex9Balance, m_balance)
      end)
    end

    :ok
  end
end

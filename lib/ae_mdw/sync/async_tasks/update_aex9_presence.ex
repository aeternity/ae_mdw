defmodule AeMdw.Sync.AsyncTasks.UpdateAex9Presence do
  @moduledoc """
  Async work to derive AEX9 presence from balance dry-running.
  """
  @behaviour AeMdw.Sync.AsyncTasks.Work

  alias AeMdw.Node.Db, as: DBN

  alias AeMdw.Database
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Log

  require Model
  require Logger

  @microsecs 1_000_000

  @spec process(args :: list()) :: :ok
  def process([contract_pk]) do
    Log.info("[update_aex9_presence] #{inspect(contract_pk)} ...")

    {time_delta, {balances, _last_block_tuple}} =
      :timer.tc(fn -> DBN.aex9_balances(contract_pk) end)

    Log.info("[update_aex9_presence] #{inspect(contract_pk)} after #{time_delta / @microsecs}s")

    {:key, height, _hash} = DBN.top_height_hash(false)
    create_txi = Origin.tx_index!({:contract, contract_pk})

    :mnesia.sync_dirty(fn ->
      Enum.each(balances, fn {{:address, account_pk}, amount} ->
        Contract.aex9_write_new_presence(contract_pk, create_txi, account_pk)

        m_balance =
          Model.aex9_balance(
            index: {contract_pk, account_pk},
            block_index: {height, -1},
            amount: amount
          )

        Database.dirty_write(Model.Aex9Balance, m_balance)
      end)
    end)

    :ok
  end
end

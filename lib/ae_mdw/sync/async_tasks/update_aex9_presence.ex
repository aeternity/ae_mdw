defmodule AeMdw.Sync.AsyncTasks.UpdateAex9State do
  @moduledoc """
  Async work to update AEX9 presence and balance through dry-run.
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
  @min_height 500_000

  @spec process(args :: list()) :: :ok
  def process([contract_pk]) do
    Log.info("[update_aex9_state] #{inspect(contract_pk)} ...")
    {_type, height, _hash} = height_hash = DBN.top_height_hash(false)

    if height > @min_height do
      {time_delta, {balances, _height_hash}} =
        :timer.tc(fn -> DBN.aex9_balances(contract_pk, height_hash) end)

      Log.info("[update_aex9_state] #{inspect(contract_pk)} after #{time_delta / @microsecs}s")

      create_txi = Origin.tx_index!({:contract, contract_pk})

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
    end

    :ok
  end
end

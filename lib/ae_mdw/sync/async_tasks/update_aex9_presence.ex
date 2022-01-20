defmodule AeMdw.Sync.AsyncTasks.UpdateAex9Presence do
  @moduledoc """
  Async work to derive AEX9 presence from balance dry-running.
  """
  @behaviour AeMdw.Sync.AsyncTasks.Work

  alias AeMdw.Node.Db, as: DBN

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

    {time_delta, {amounts, _last_block_tuple}} =
      :timer.tc(fn -> DBN.aex9_balances(contract_pk) end)

    Log.info("[update_aex9_presence] #{inspect(contract_pk)} after #{time_delta / @microsecs}s")

    create_txi = Origin.tx_index!({:contract, contract_pk})

    :mnesia.sync_dirty(fn ->
      Enum.each(amounts, fn {{:address, account_pk}, _amount} ->
        Contract.aex9_write_new_presence(contract_pk, create_txi, account_pk)
      end)
    end)

    :ok
  end
end

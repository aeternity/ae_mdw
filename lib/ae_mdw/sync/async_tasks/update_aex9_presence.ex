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

  @spec process(args :: list()) :: :ok
  def process([contract_pk]) do
    Log.info("[update_aex9_state] #{inspect(contract_pk)} ...")
    {{kbi, mbi} = block_index, call_txi} = get_call_bi_and_txi(contract_pk)

    {time_delta, {balances, _height_hash}} =
      :timer.tc(fn ->
        next_kb_hash = DBN.get_key_block_hash(kbi + 1)
        next_hash = DBN.get_next_hash(next_kb_hash, mbi)
        type = if next_hash == next_kb_hash, do: :key, else: :micro

        DBN.aex9_balances(contract_pk, {type, kbi, next_hash})
      end)

    Log.info("[update_aex9_state] #{inspect(contract_pk)} after #{time_delta / @microsecs}s")

    create_txi = Origin.tx_index!({:contract, contract_pk})

    Enum.each(balances, fn {{:address, account_pk}, amount} ->
      Contract.aex9_write_new_presence(contract_pk, create_txi, account_pk)

      m_balance =
        Model.aex9_balance(
          index: {contract_pk, account_pk},
          block_index: block_index,
          txi: call_txi,
          amount: amount
        )

      Database.dirty_write(Model.Aex9Balance, m_balance)
    end)

    :ok
  end

  defp get_call_bi_and_txi(contract_pk) do
    case :ets.lookup(:aex9_sync_cache, contract_pk) do
      [{^contract_pk, block_index, call_txi}] ->
        {block_index, call_txi}

      [] ->
        create_txi = Origin.tx_index!({:contract, contract_pk})
        Model.tx(block_index: block_index) = Database.fetch!(Model.Tx, create_txi)
        {block_index, create_txi}
    end
  end
end

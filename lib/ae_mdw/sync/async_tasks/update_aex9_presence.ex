defmodule AeMdw.Sync.AsyncTasks.UpdateAex9State do
  @moduledoc """
  Async work to update AEX9 presence and balance through dry-run.
  """
  @behaviour AeMdw.Sync.AsyncTasks.Work

  alias AeMdw.Node.Db, as: DBN

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.UpdateAex9PresenceMutation
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
        Model.block(hash: next_kb_hash) = Database.fetch!(Model.Block, {kbi + 1, -1})
        next_hash = DBN.get_next_hash(next_kb_hash, mbi)
        type = if next_hash == next_kb_hash, do: :key, else: :micro

        DBN.aex9_balances(contract_pk, {type, kbi, next_hash})
      end)

    Log.info("[update_aex9_state] #{inspect(contract_pk)} after #{time_delta / @microsecs}s")

    balances = Enum.map(balances, fn {{:address, account_pk}, amount} -> {account_pk, amount} end)

    mutation = UpdateAex9PresenceMutation.new(contract_pk, block_index, call_txi, balances)
    State.commit(State.new(), [mutation])

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

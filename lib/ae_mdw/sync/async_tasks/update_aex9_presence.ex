defmodule AeMdw.Sync.AsyncTasks.UpdateAex9State do
  @moduledoc """
  Async work to update AEX9 presence and balance through dry-run.
  """
  @behaviour AeMdw.Sync.AsyncTasks.Work

  alias AeMdw.Node.Db, as: DBN

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.UpdateAex9PresenceMutation
  alias AeMdw.Log

  require Model
  require Logger

  @microsecs 1_000_000

  @spec process(args :: list()) :: :ok
  def process([contract_pk, {kbi, mbi} = block_index, call_txi]) do
    Log.info("[update_aex9_state] #{inspect(enc_ct(contract_pk))} ...")

    {time_delta, {balances, _height_hash}} =
      :timer.tc(fn ->
        next_kb_hash = DBN.get_key_block_hash(kbi + 1)
        next_hash = DBN.get_next_hash(next_kb_hash, mbi)
        type = if next_hash == next_kb_hash, do: :key, else: :micro

        DBN.aex9_balances(contract_pk, {type, kbi, next_hash})
      end)

    Log.info(
      "[update_aex9_state] #{inspect(enc_ct(contract_pk))} after #{time_delta / @microsecs}s"
    )

    balances = Enum.map(balances, fn {{:address, account_pk}, amount} -> {account_pk, amount} end)

    mutation = UpdateAex9PresenceMutation.new(contract_pk, block_index, call_txi, balances)
    State.commit(State.new(), [mutation])

    :ok
  end

  defp enc_ct(<<pk::binary-32>>), do: :aeser_api_encoder.encode(:contract_pubkey, pk)
  defp enc_ct(invalid_pk), do: invalid_pk
end

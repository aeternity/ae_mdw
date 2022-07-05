defmodule AeMdw.Sync.AsyncTasks.UpdateAex9State do
  @moduledoc """
  Async work to update AEX9 presence and balance through dry-run.
  """
  @behaviour AeMdw.Sync.AsyncTasks.Work

  alias AeMdw.Node.Db, as: DBN

  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.UpdateAex9StateMutation
  alias AeMdw.Log

  require Model
  require Logger

  @microsecs 1_000_000

  @spec process(args :: list()) :: :ok
  def process([contract_pk, _block_index, _call_txi] = args) do
    Log.info("[update_aex9_state] #{inspect(enc_ct(contract_pk))} ...")

    {time_delta, mutations} = :timer.tc(fn -> mutations(args) end)

    Log.info(
      "[update_aex9_state] #{inspect(enc_ct(contract_pk))} after #{time_delta / @microsecs}s"
    )

    State.commit(State.new(), mutations)

    :ok
  end

  @spec mutations(args :: list()) :: [Mutation.t()]
  def mutations([contract_pk, {kbi, mbi} = block_index, call_txi]) do
    next_kb_hash = DBN.get_key_block_hash(kbi + 1)
    next_hash = DBN.get_next_hash(next_kb_hash, mbi)
    type = if next_hash == next_kb_hash, do: :key, else: :micro

    {balances, _height_hash} = DBN.aex9_balances(contract_pk, {type, kbi, next_hash})

    if map_size(balances) == 0 do
      m_empty_balance = Model.aex9_balance(index: {contract_pk, <<>>})

      [
        WriteMutation.new(Model.Aex9Balance, m_empty_balance)
      ]
    else
      balances =
        Enum.map(balances, fn {{:address, account_pk}, amount} -> {account_pk, amount} end)

      [
        UpdateAex9StateMutation.new(contract_pk, block_index, call_txi, balances)
      ]
    end
  end

  defp enc_ct(<<pk::binary-32>>), do: :aeser_api_encoder.encode(:contract_pubkey, pk)
  defp enc_ct(invalid_pk), do: invalid_pk
end

defmodule AeMdw.Sync.AsyncTasks.UpdateAex9State do
  @moduledoc """
  Async work to update AEX9 presence and balance through dry-run.
  """
  @behaviour AeMdw.Sync.AsyncTasks.Work

  alias AeMdw.Db.Model
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.UpdateAex9StateMutation
  alias AeMdw.Sync.Aex9Balances
  alias AeMdw.Log

  alias AeMdw.Sync.AsyncStoreServer

  require Model
  require Logger

  import AeMdw.Util.Encoding, only: [encode_contract: 1]

  @microsecs 1_000_000

  @spec process(args :: list(), done_fn :: fun()) :: :ok
  def process([contract_pk, block_index, _call_txi] = args, done_fn) do
    {time_delta, :ok} =
      :timer.tc(fn ->
        case Aex9Balances.get_balances(contract_pk, block_index) do
          {:ok, balances, purge_balances} ->
            write_mutation = mutation(args, balances)
            delete_mutation = Aex9Balances.purge_mutation(contract_pk, purge_balances)

            AsyncStoreServer.write_mutations(
              block_index,
              [
                delete_mutation,
                write_mutation
              ],
              done_fn
            )

          {:error, _reason} ->
            done_fn.()
        end

        :ok
      end)

    Log.info(
      "[update_aex9_state] #{encode_contract(contract_pk)} after #{time_delta / @microsecs}s"
    )

    :ok
  end

  defp mutation([contract_pk, block_index, call_txi], balances) do
    if balances == [] do
      m_empty_balance = Model.aex9_balance(index: {contract_pk, <<>>})
      WriteMutation.new(Model.Aex9Balance, m_empty_balance)
    else
      UpdateAex9StateMutation.new(contract_pk, block_index, call_txi, balances)
    end
  end
end

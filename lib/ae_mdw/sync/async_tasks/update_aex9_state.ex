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
  def process([contract_pk, block_index, call_txi], done_fn) do
    {time_delta, :ok} =
      :timer.tc(fn ->
        case Aex9Balances.get_balances(contract_pk, block_index) do
          {:ok, balances, _purged_balances} ->
            {async_mutations, flush_mutations} = mutations(contract_pk, call_txi, balances)

            AsyncStoreServer.write_mutations(async_mutations, done_fn, flush_mutations)

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

  defp mutations(contract_pk, _call_txi, []) do
    m_empty_balance = Model.aex9_event_balance(index: {contract_pk, <<>>})

    {[WriteMutation.new(Model.Aex9EventBalance, m_empty_balance)], []}
  end

  # written on the database state: on AsyncStore, which doesn't read through to
  # the database, the balances events refreshed since the creation and the
  # contract's total would be overwritten
  defp mutations(contract_pk, call_txi, balances) do
    {[], [UpdateAex9StateMutation.new(contract_pk, call_txi, balances)]}
  end
end

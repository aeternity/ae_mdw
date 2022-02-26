defmodule AeMdw.Migrations.Aex9TransfersPerTxi do
  @moduledoc """
  Reindexes Aex9 transfers per txi for each sender or recipient.

  The new table is created to keep the indexing for sender-recipient pairs but sorted by txi.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Database
  alias AeMdw.Log

  require Ex2ms
  require Model

  @doc """
  Runs reindexation within an atomic change.
  """
  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    transfer_keys = Database.dirty_all_keys(Model.Aex9Transfer)

    {:atomic, :ok} =
      :mnesia.sync_transaction(fn ->
        transfer_keys
        |> Stream.map(&Database.fetch!(Model.Aex9Transfer, &1))
        |> Stream.map(fn Model.aex9_transfer(index: {from, to, amount, txi, idx}) ->
          Database.delete(Model.Aex9Transfer, {from, to, amount, txi, idx})
          Database.delete(Model.RevAex9Transfer, {to, from, amount, txi, idx})

          m_transfer = Model.aex9_transfer(index: {from, txi, to, amount, idx})
          m_rev_transfer = Model.rev_aex9_transfer(index: {to, txi, from, amount, idx})
          m_pair_transfer = Model.aex9_pair_transfer(index: {from, to, txi, amount, idx})

          Database.write(Model.Aex9Transfer, m_transfer)
          Database.write(Model.RevAex9Transfer, m_rev_transfer)
          Database.write(Model.Aex9PairTransfer, m_pair_transfer)
        end)
        |> Stream.run()
      end)

    indexed_count = length(transfer_keys)

    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end
end

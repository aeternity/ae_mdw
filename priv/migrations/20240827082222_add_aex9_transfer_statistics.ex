defmodule AeMdw.Migrations.AddAex9TransferStatistics do
  @moduledoc """
  Creates statistics relevant to AEX9 token transfers.
  """
  alias AeMdw.Collection
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Stats, as: SyncStats
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.Util

  require AeMdw.Db.Model, as: Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    key_boundary =
      Collection.generate_key_boundary({
        :aex9,
        Collection.binary(),
        Collection.integer(),
        Collection.binary(),
        Collection.integer(),
        Collection.integer()
      })

    mutations_length =
      state
      |> Collection.stream(Model.AexnTransfer, :forward, key_boundary, nil)
      |> Stream.flat_map(fn {:aex9, _from_pk, txi, _to_pk, _amount, _log_idx} ->
        time = Util.txi_to_time(state, txi)

        time
        |> SyncStats.time_intervals()
        |> Enum.map(fn {interval_by, interval_start} ->
          {:aex9_transfers, interval_by, interval_start}
        end)
      end)
      |> Enum.frequencies()
      |> Enum.map(fn {index, count} ->
        WriteMutation.new(Model.Statistic, Model.statistic(index: index, count: count))
      end)
      |> Enum.chunk_every(1000)
      |> Enum.map(fn mutations ->
        _state = State.commit_db(state, mutations)
        length(mutations)
      end)
      |> Enum.sum()

    {:ok, mutations_length}
  end
end

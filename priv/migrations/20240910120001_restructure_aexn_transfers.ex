defmodule AeMdw.Migrations.RestructureAexnTransfers do
  @moduledoc """
  Reindex AExN transfers to sort them by (txi, idx).
  """
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.WriteMutation

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    transfer_mutations =
      state
      |> Collection.stream(Model.AexnTransfer, nil)
      |> Stream.filter(fn {_aexn_type, _from_pk, _txi, to_pk, _value, _log_idx} ->
        is_binary(to_pk)
      end)
      |> Stream.map(fn {aexn_type, from_pk, txi, to_pk, value, log_idx} = key ->
        aexn_transfer = State.fetch!(state, Model.AexnTransfer, key)

        {
          WriteMutation.new(
            Model.AexnTransfer,
            Model.aexn_transfer(aexn_transfer,
              index: {aexn_type, from_pk, txi, log_idx, to_pk, value}
            )
          ),
          key
        }
      end)

    rev_transfer_mutations =
      state
      |> Collection.stream(Model.RevAexnTransfer, nil)
      |> Stream.map(fn {aexn_type, to_pk, txi, from_pk, value, log_idx} = key ->
        {
          WriteMutation.new(
            Model.RevAexnTransfer,
            Model.rev_aexn_transfer(index: {aexn_type, to_pk, txi, log_idx, from_pk, value})
          ),
          key
        }
      end)

    pair_transfer_mutations =
      state
      |> Collection.stream(Model.AexnPairTransfer, nil)
      |> Stream.map(fn {aexn_type, from_pk, to_pk, txi, value, log_idx} = key ->
        {
          WriteMutation.new(
            Model.AexnPairTransfer,
            Model.aexn_pair_transfer(index: {aexn_type, from_pk, to_pk, txi, log_idx, value})
          ),
          key
        }
      end)

    transfers_length = replace_keys(state, Model.AexnTransfer, transfer_mutations)
    rev_transfers_length = replace_keys(state, Model.RevAexnTransfer, rev_transfer_mutations)
    pair_transfers_length = replace_keys(state, Model.AexnPairTransfer, pair_transfer_mutations)

    {:ok, transfers_length + rev_transfers_length + pair_transfers_length}
  end

  defp replace_keys(_state, table, zipped_mutations) do
    zipped_mutations
    |> Stream.chunk_every(1_000)
    |> Stream.map(fn chunk ->
      {mutations, deletion_keys} = Enum.unzip(chunk)

      _mutations = [
        DeleteKeysMutation.new(%{table => deletion_keys}) | mutations
      ]

      # _state = State.commit_db(state, mutations)
      length(mutations)
    end)
    |> Enum.sum()
  end
end

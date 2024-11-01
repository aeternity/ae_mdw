defmodule AeMdw.Migrations.AddEpochInfo do
  @moduledoc """
  Generate epoch info for hyperchain.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Hyperchain

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    stream =
      Stream.resource(
        fn -> 1 end,
        fn height ->
          case Hyperchain.epoch_info_at_height(height) do
            {:ok, %{last: last} = epoch_info} -> {[epoch_info], last + 1}
            :error -> {:halt, height}
          end
        end,
        fn _ -> :ok end
      )

    stream
    |> Stream.map(fn %{
                       first: first,
                       last: last,
                       length: length,
                       seed: seed,
                       epoch: epoch,
                       validators: validators
                     } ->
      WriteMutation.new(
        Model.EpochInfo,
        Model.epoch_info(
          index: epoch,
          first: first,
          last: last,
          length: length,
          seed: seed,
          validators: validators
        )
      )
    end)
    |> Stream.chunk_every(1000)
    |> Stream.map(fn mutations ->
      _new_state = State.commit_db(state, mutations)

      length(mutations)
    end)
    |> Enum.sum()
    |> then(&{:ok, &1})
  end
end

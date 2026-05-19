defmodule AeMdw.Migrations.AddBlocksTimeIndex do
  @moduledoc """
  Add the time index to the blocks table for key blocks.
  """
  alias AeMdw.Db.State
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.Model
  alias AeMdw.Db.WriteMutation

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    Model.Block
    |> RocksDbCF.stream()
    |> Stream.filter(fn Model.block(index: {_height, mbi}) ->
      mbi == -1
    end)
    |> Stream.chunk_every(1000)
    |> Task.async_stream(fn blocks ->
      Enum.map(blocks, fn Model.block(index: {height, _mbi}, hash: hash) ->
        header =
          :aec_db.get_header(hash)

        time =
          :aec_headers.time_in_msecs(header)

        miner =
          :aec_headers.beneficiary(header)

        WriteMutation.new(
          Model.KeyBlockTime,
          Model.key_block_time(index: time, height: height, miner: miner)
        )
      end)
    end)
    |> Stream.map(fn {:ok, mutations} ->
      _state = State.commit_db(state, mutations)
      length(mutations)
    end)
    |> Enum.sum()
    |> then(&{:ok, &1})
  end
end

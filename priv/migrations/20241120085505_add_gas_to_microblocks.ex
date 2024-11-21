defmodule AeMdw.Migrations.AddGasToMicroblocks do
  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.WriteMutation
  import Record, only: [defrecord: 2]

  require Model

  defrecord :block, index: nil, tx_index: nil, hash: nil

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    Model.Block
    |> RocksDbCF.stream()
    |> Stream.filter(fn block ->
      case block do
        block(index: {_h, i}) -> i != -1
        Model.block(index: {_h, i}, gas: nil) -> i != -1
        Model.block() -> false
      end
    end)
    |> Stream.map(fn block(index: index, tx_index: tx_index, hash: hash) ->
      gas =
        hash
        |> :aec_db.get_block()
        |> :aec_blocks.gas()

      new_mb = Model.block(index: index, tx_index: tx_index, hash: hash, gas: gas)

      WriteMutation.new(Model.Block, new_mb)
    end)
    |> Stream.chunk_every(1000)
    |> Stream.map(fn mutations ->
      _state = State.commit_db(state, mutations)
      length(mutations)
    end)
    |> Enum.sum()
    |> then(&{:ok, &1})
  end
end

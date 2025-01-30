defmodule AeMdw.Migrations.PopulateTxsFeeField do
  require Record
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Node.Db, as: NodeDb

  require Model

  import Record, only: [defrecord: 2]

  defrecord :tx,
    index: nil,
    id: nil,
    block_index: nil,
    time: nil

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(_state, _from_start?) do
    RocksDbCF.stream(Model.Tx)
    |> Stream.map(fn tx(index: index, id: tx_hash, block_index: bi, time: time) ->
        fee = NodeDb.get_tx_fee!(tx_hash)
        new_tx = Model.tx(index: index, id: tx_hash, block_index: bi, time: time, fee: fee)

        IO.inspect(fee, label: "fee")

        WriteMutation.new(Model.Tx, new_tx)
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

defmodule AeMdw.Migrations.AddFeeToTxs do
  @moduledoc """
  Add the tx fees to the tx table in order to skip fetching them from the node every time.
  """
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Node.Db, as: NodeDb

  import Record, only: [defrecord: 2]

  require Model

  defrecord(:tx, index: nil, id: nil, block_index: nil, time: nil)

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    Model.Tx
    |> RocksDbCF.stream()
    |> Stream.chunk_every(1000)
    |> Task.async_stream(
      fn txs ->
        Enum.map(txs, fn tx(index: index, id: id, block_index: block_index, time: time) ->
          fee = NodeDb.get_tx_fee(id)
          tx = Model.tx(index: index, id: id, block_index: block_index, time: time, fee: fee)

          WriteMutation.new(Model.Tx, tx)
        end)
      end,
      timeout: :infinity
    )
    |> Stream.map(fn {:ok, mutations} ->
      _state = State.commit_db(state, mutations)

      length(mutations)
    end)
    |> Enum.sum()
    |> then(&{:ok, &1})
  end
end

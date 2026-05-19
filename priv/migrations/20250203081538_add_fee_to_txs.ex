defmodule AeMdw.Migrations.AddFeeToTxs do
  @moduledoc """
  Add the tx fees to the tx table in order to skip fetching them from the node every time.
  """
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Node.Db, as: NodeDb

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    Model.Tx
    |> RocksDbCF.stream()
    |> Stream.chunk_every(1000)
    |> Task.async_stream(
      fn txs ->
        Enum.map(txs, fn tx_record ->
          index = Model.tx(tx_record, :index)
          id = Model.tx(tx_record, :id)
          block_index = Model.tx(tx_record, :block_index)
          time = Model.tx(tx_record, :time)

          fee = if(id, do: NodeDb.get_tx_fee(id), else: nil) || tx_fee(tx_record)
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

  defp tx_fee(tx_record) when tuple_size(tx_record) == tuple_size(Model.tx()),
    do: Model.tx(tx_record, :fee)

  defp tx_fee(_tx_record), do: nil
end

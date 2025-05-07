defmodule AeMdw.Migrations.AddAccumulatedFeeToTxs do
  @moduledoc """
  Adds the new accumulated fee field to tx.
  """
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Db.State
  alias AeMdw.Db.Model

  import Record, only: [defrecord: 2]

  require Model
  require Logger

  defrecord(:tx, index: nil, id: nil, block_index: nil, time: nil, fee: nil)

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, from_start?) do
    case DbUtil.last_txi(state) do
      {:ok, last_txi} -> run(state, from_start?, last_txi)
      :none -> {:ok, 0}
    end
  end

  defp run(state, _from_start?, last_txi) do
    1..last_txi
    |> Stream.map(&State.fetch!(state, Model.Tx, &1))
    |> Stream.transform(0, fn
      tx(index: index, id: id, block_index: block_index, time: time, fee: fee), acc_fee ->
        acc_fee = acc_fee + fee

        if rem(index, 10_000) == 0 do
          Logger.info("Processed #{index} out of #{last_txi}")
        end

        tx =
          Model.tx(
            index: index,
            id: id,
            block_index: block_index,
            time: time,
            fee: fee,
            accumulated_fee: acc_fee
          )

        {[WriteMutation.new(Model.Tx, tx)], acc_fee}

      Model.tx(accumulated_fee: acc_fee), _acc_fee ->
        {[], acc_fee}
    end)
    |> Stream.chunk_every(10_000)
    |> Stream.map(fn mutations ->
      _state = State.commit_db(state, mutations)

      length(mutations)
    end)
    |> Enum.sum()
    |> then(&{:ok, &1})
  end
end

defmodule AeMdw.Migrations.AddInnerTxTypeIndex do
  @moduledoc """
  Indexes Model.InnerType table
  """

  alias AeMdw.Collection
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.InnerTx
  alias AeMdw.Node.Db
  alias AeMdw.Util

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    mutations =
      ~w(paying_for_tx ga_meta_tx)a
      |> Enum.flat_map(fn tx_type ->
        scope = {{tx_type, Util.min_int()}, {tx_type, Util.max_int()}}

        state
        |> Collection.stream(Model.Type, :forward, scope, nil)
        |> Stream.map(fn {tx_type, txi} ->
          Model.tx(id: tx_hash) = State.fetch!(state, Model.Tx, txi)
          {_block_hash, ^tx_type, _signed_tx, tx_rec} = Db.get_tx_data(tx_hash)

          {inner_type, _tx} =
            tx_type
            |> InnerTx.signed_tx(tx_rec)
            |> :aetx_sign.tx()
            |> :aetx.specialize_type()

          WriteMutation.new(Model.InnerType, Model.type(index: {inner_type, txi}))
        end)
      end)

    _new_state = State.commit(state, mutations)

    {:ok, length(mutations)}
  end
end

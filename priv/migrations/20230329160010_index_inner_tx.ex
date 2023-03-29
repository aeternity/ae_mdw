defmodule AeMdw.Migrations.IndexGameta do
  @moduledoc """
  Index GaMetaTx.
  """

  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.WriteFieldsMutation
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync.InnerTx
  alias AeMdw.Node.Db
  alias AeMdw.Db.State

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    write_mutations =
      [:ga_meta_tx, :paying_for_tx]
      |> Stream.flat_map(fn tx_type ->
        key_boundary = {{tx_type, 1, <<>>, 0}, {tx_type, 1, AeMdw.Util.max_256bit_bin(), nil}}

        state
        |> Collection.stream(Model.Field, :forward, key_boundary, nil)
        |> Stream.flat_map(fn {_tx_type, _pos, _pubkey, txi} ->
          Model.tx(block_index: block_index, id: hash) = State.fetch!(state, Model.Tx, txi)
          {_block_hash, ^tx_type, _signed_tx, tx_rec} = Db.get_tx_data(hash)
          inner_signed_tx = InnerTx.signed_tx(tx_type, tx_rec)
          {inner_type, inner_tx} = :aetx.specialize_type(:aetx_sign.tx(inner_signed_tx))

          [
            WriteMutation.new(Model.Type, Model.type(index: {tx_type, txi})),
            WriteFieldsMutation.new(inner_type, inner_tx, block_index, txi, tx_type)
          ]
        end)
      end)
      |> Enum.to_list()

    _state = State.commit(state, write_mutations)

    {:ok, length(write_mutations)}
  end
end

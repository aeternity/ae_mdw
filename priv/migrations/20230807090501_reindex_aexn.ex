defmodule AeMdw.Migrations.ReindexAexN do
  @moduledoc """
  Re-indexes AEX9.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync
  alias AeMdw.Node

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    mutations =
      state
      |> Collection.stream(
        Model.Type,
        :forward,
        {{:contract_create_tx, 0}, {:contract_create_tx, nil}},
        nil
      )
      |> Stream.map(&State.fetch!(state, Model.Tx, elem(&1, 1)))
      |> Enum.flat_map(fn Model.tx(index: txi, block_index: block_index, id: hash) ->
        with {block_hash, _type, _signed_tx, tx_rec} <- Node.Db.get_tx_data(hash),
             contract_pk <- :aect_create_tx.contract_pubkey(tx_rec),
             true <- not already_indexed(state, contract_pk) do
          [Sync.Contract.aexn_create_contract_mutation(contract_pk, block_hash, block_index, txi)]
        else
          _bool ->
            []
        end
      end)
      |> Enum.reject(&is_nil/1)

    _state = State.commit(state, mutations)

    {:ok, length(mutations)}
  end

  defp already_indexed(state, contract_pk) do
    State.exists?(state, Model.AexnContract, {:aex9, contract_pk}) or
      State.exists?(state, Model.AexnContract, {:aex141, contract_pk})
  end
end

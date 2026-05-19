defmodule AeMdw.Migrations.FixNameAndSymbolSwappedInAexnContracts do
  @moduledoc """
  Fixes the name and symbol on some AEXN contracts.
  This migration is needed because the name and symbol were put in the wrong order in the db
  when the contracts were created. This is because the name and symbol were checked if name > symbol which would suggest that the shorter is the symbol, but this actually checked the lexicographic order of the strings, not the length.
  """
  alias AeMdw.Db.WriteMutation
  alias AeMdw.AexnContracts
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    Model.AexnContract
    |> RocksDbCF.stream()
    |> Stream.flat_map(fn aexn_contract -> updated_contract_mutations(state, aexn_contract) end)
    |> Stream.chunk_every(1000)
    |> Stream.map(fn mutations ->
      _state = State.commit_db(state, mutations)
      length(mutations)
    end)
    |> Enum.sum()
    |> then(fn count ->
      {:ok, count}
    end)
  end

  defp updated_contract_mutations(
         state,
         Model.aexn_contract(index: {aexn_type, contract_pk}, txi_idx: {txi, _idx}) =
           aexn_contract
       ) do
    with {:ok, tx} <- State.get(state, Model.Tx, txi),
         block_index when not is_nil(block_index) <- Model.tx(tx, :block_index),
         {:ok, Model.block(hash: block_hash)} <- State.get(state, Model.Block, block_index),
         {:ok, new_meta_info} <- AexnContracts.call_meta_info(aexn_type, contract_pk, block_hash) do
      [
        WriteMutation.new(
          Model.AexnContract,
          Model.aexn_contract(aexn_contract, meta_info: new_meta_info)
        )
      ]
    else
      _missing_data -> []
    end
  end
end

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
    |> Stream.flat_map(fn Model.aexn_contract(
                            index: {aexn_type, contract_pk},
                            txi_idx: {txi, _idx}
                          ) = aexn_contract ->
      Model.tx(block_index: bi) = State.fetch!(state, Model.Tx, txi)
      Model.block(hash: block_hash) = State.fetch!(state, Model.Block, bi)

      aexn_type
      |> AexnContracts.call_meta_info(contract_pk, block_hash)
      |> case do
        {:ok, new_meta_info} ->
          [
            WriteMutation.new(
              Model.AexnContract,
              Model.aexn_contract(
                aexn_contract,
                meta_info: new_meta_info
              )
            )
          ]

        :error ->
          []
      end
    end)
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
end

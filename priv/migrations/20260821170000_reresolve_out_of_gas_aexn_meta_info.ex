defmodule AeMdw.Migrations.ReresolveOutOfGasAexnMetaInfo do
  @moduledoc """
  Re-resolves the meta_info of AEX-9/AEX-141 contracts stuck with the
  out_of_gas_error sentinel from before the meta_info/extensions dry-run gas
  budget fix. Only contracts with that exact sentinel are re-dry-run; a
  format_error is a decode mismatch, not a gas problem, and retrying it would
  fail identically.
  """

  alias AeMdw.AexnContracts
  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    Model.AexnContract
    |> RocksDbCF.stream()
    |> Stream.filter(fn Model.aexn_contract(meta_info: meta_info) ->
      elem(meta_info, 0) == :out_of_gas_error
    end)
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
              Model.aexn_contract(aexn_contract, meta_info: new_meta_info)
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
    |> then(fn count -> {:ok, count} end)
  end
end

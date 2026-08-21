defmodule AeMdw.Migrations.IndexMissingAexnContracts do
  @moduledoc """
  Re-indexes AEX-9/AEX-141 contracts that were silently skipped entirely at
  creation time (never written to Model.AexnContract) because
  aexn_create_contract_mutation/4's `with` chain returns nil on any failed
  step - including the aex9_extensions/aex141_extensions dry-run running out
  of gas before the meta_info/extensions gas budget fix. Every still-unindexed
  contract_create_tx contract is cheaply classified first, so the actual
  dry-run calls only run for the ones that are AEX-9/AEX-141-shaped.
  """

  alias AeMdw.AexnContracts
  alias AeMdw.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Contract, as: SyncContract

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    count =
      Model.Origin
      |> RocksDbCF.stream()
      |> Stream.filter(fn Model.origin(index: {tx_type, _contract_pk}) ->
        tx_type == :contract_create_tx
      end)
      |> Stream.reject(fn Model.origin(index: {_tx_type, contract_pk}) ->
        State.exists?(state, Model.AexnContract, {:aex9, contract_pk}) or
          State.exists?(state, Model.AexnContract, {:aex141, contract_pk})
      end)
      |> Stream.flat_map(fn Model.origin(
                              index: {_tx_type, contract_pk},
                              txi_idx: {txi, _idx} = txi_idx
                            ) ->
        Model.tx(block_index: {height, _mbi} = block_index) = State.fetch!(state, Model.Tx, txi)

        if aexn_shaped?(height, contract_pk) do
          Model.block(hash: block_hash) = State.fetch!(state, Model.Block, block_index)

          case SyncContract.aexn_create_contract_mutation(
                 contract_pk,
                 block_hash,
                 block_index,
                 txi_idx
               ) do
            nil -> []
            mutation -> [mutation]
          end
        else
          []
        end
      end)
      |> Stream.chunk_every(100)
      |> Stream.map(fn mutations ->
        _state = State.commit_db(state, mutations)
        length(mutations)
      end)
      |> Enum.sum()

    {:ok, count}
  end

  defp aexn_shaped?(height, contract_pk) do
    case Contract.get_info(contract_pk) do
      {:ok, {type_info, _compiler_vsn, _source_hash}} ->
        AexnContracts.aex9?(type_info) or AexnContracts.has_aex141_signatures?(height, type_info)

      {:error, _reason} ->
        false
    end
  end
end

defmodule AeMdw.Migrations.Aex9ContractValueTransfers do
  # credo:disable-for-this-file
  @moduledoc """
  Index aex9 mint and burn as transfers.
  """

  alias AeMdw.Db.Origin
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model

  import AeMdw.Migrations.LogsHelper

  @mint_hash <<215, 0, 247, 67, 100, 22, 167, 140, 76, 197, 95, 144, 242, 214, 49, 111, 60, 169,
               26, 213, 244, 50, 59, 170, 72, 182, 90, 72, 178, 84, 251, 35>>

  @burn_hash <<131, 150, 191, 31, 191, 94, 29, 68, 10, 143, 62, 247, 169, 46, 221, 88, 138, 150,
               176, 154, 87, 110, 105, 73, 173, 237, 42, 252, 105, 193, 146, 6>>

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    mint_mutations = event_mutations(state, @mint_hash)
    burn_mutations = event_mutations(state, @burn_hash)

    mutations = mint_mutations ++ burn_mutations
    _state = State.commit_db(state, mutations)

    {:ok, length(mutations)}
  end

  defp event_mutations(state, evt_hash) do
    state
    |> event_boundaries(evt_hash)
    |> Task.async_stream(
      fn key_boundary ->
        state
        |> stream_contract_logs_by_events(key_boundary)
        |> Enum.map(&aexn_transfer_mutation(state, &1))
        |> Enum.reject(&is_nil/1)
      end,
      timeout: :infinity
    )
    |> Enum.flat_map(fn {:ok, mutations} -> mutations end)
  end

  defp aexn_transfer_mutation(
         state,
         Model.contract_log(
           index: {contract_txi, txi, idx},
           hash: evt_hash,
           args: [pk, <<value::256>>]
         )
       ) do
    contract_pk = Origin.pubkey!(state, {:contract, contract_txi})

    m_transfer =
      if evt_hash == @mint_hash do
        Model.aexn_transfer(
          index: {:aex9, contract_pk, txi, pk, value, idx},
          contract_pk: contract_pk
        )
      else
        Model.aexn_transfer(
          index: {:aex9, pk, txi, nil, value, idx},
          contract_pk: contract_pk
        )
      end

    WriteMutation.new(Model.AexnTransfer, m_transfer)
  end

  defp aexn_transfer_mutation(_state, _other_log), do: nil
end

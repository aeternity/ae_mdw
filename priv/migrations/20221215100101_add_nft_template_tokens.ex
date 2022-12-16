defmodule AeMdw.Migrations.AddNftTemplateTokens do
  @moduledoc """
  Add edition supply for nft templates.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Origin
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Stats, as: SyncStats

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    burns =
      state
      |> get_logs("Burn")
      |> Stream.flat_map(fn Model.contract_log(
                              index: {create_txi, _call_txi, _event_hash, _log_idx},
                              args: args
                            ) ->
        case args do
          [<<token_id::256>>] -> [{create_txi, token_id}]
          _other_args -> []
        end
      end)
      |> Enum.to_list()

    count =
      state
      |> get_logs("TemplateMint")
      |> Enum.map(fn Model.contract_log(
                       index: {create_txi, call_txi, _event_hash, log_idx},
                       args: args
                     ) ->
        with [<<_pk::256>>, <<_template_id::256>>, <<token_id::256>>] <- args,
             true <- {create_txi, token_id} not in burns do
          contract_pk = Origin.pubkey!(state, {:contract, create_txi})

          _state =
            write_aex141_records(state, :template_mint, contract_pk, call_txi, log_idx, args)

          1
        else
          _other_args ->
            0
        end
      end)
      |> Enum.sum()

    {:ok, count}
  end

  defp get_logs(state, event_name) do
    event_hash = :aec_hash.blake2b_256_hash(event_name)

    state
    |> Collection.stream(
      Model.EvtContractLog,
      :forward,
      {{event_hash, 0, 0, 0}, {event_hash, nil, nil, nil}},
      nil
    )
    |> Stream.map(fn {event_hash, call_txi, create_txi, log_idx} ->
      {create_txi, call_txi, event_hash, log_idx}
    end)
    |> Stream.map(&State.fetch!(state, Model.ContractLog, &1))
  end

  defp write_aex141_records(
         state,
         :template_mint,
         contract_pk,
         txi,
         log_idx,
         [<<_pk::256>>, <<template_id::256>>, <<token_id::256>>] = args
       ) do
    state
    |> Contract.write_aex141_ownership(contract_pk, args)
    |> State.put(
      Model.NftTokenTemplate,
      Model.nft_token_template(index: {contract_pk, token_id}, template: template_id)
    )
    |> State.put(
      Model.NftTemplateToken,
      Model.nft_template_token(
        index: {contract_pk, template_id, token_id},
        txi: txi,
        log_idx: log_idx
      )
    )
    |> SyncStats.increment_nft_template_tokens(contract_pk, template_id)
  end
end

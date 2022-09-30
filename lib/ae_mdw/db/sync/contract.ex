defmodule AeMdw.Db.Sync.Contract do
  @moduledoc """
  Saves contract indexed state for creation, calls and events.
  """
  alias AeMdw.Blocks
  alias AeMdw.Contract
  alias AeMdw.AexnContracts
  alias AeMdw.Db.IntCallsMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.NameTransferMutation
  alias AeMdw.Db.NameRevokeMutation
  alias AeMdw.Db.Sync.Oracle
  alias AeMdw.Db.AexnCreateContractMutation
  alias AeMdw.Db.ContractCreateCacheMutation
  alias AeMdw.Db.Sync.Origin, as: SyncOrigin
  alias AeMdw.Db.Sync.Name
  alias AeMdw.Node.Db
  alias AeMdw.Validate
  alias AeMdw.Txs

  require Model

  @type call_record() :: tuple()

  @spec child_contract_mutations(
          Contract.fun_arg_res_or_error(),
          Blocks.block_index(),
          Txs.txi(),
          Txs.tx_hash()
        ) :: [Mutation.t()]
  def child_contract_mutations({:error, _any}, _block_index, _txi, _tx_hash), do: []

  def child_contract_mutations(%{result: fun_result}, block_index, txi, tx_hash) do
    with %{type: :contract, value: contract_id} <- fun_result,
         {:ok, contract_pk} <- Validate.id(contract_id) do
      [
        aexn_create_contract_mutation(contract_pk, block_index, txi)
        | SyncOrigin.origin_mutations(:contract_call_tx, nil, contract_pk, txi, tx_hash)
      ]
    else
      _no_child_contract -> []
    end
  end

  @spec events_mutations(
          [Contract.event()],
          Blocks.block_index(),
          Blocks.block_hash(),
          Txs.txi(),
          Txs.tx_hash(),
          Db.pubkey()
        ) :: [
          Mutation.t()
        ]
  def events_mutations(events, block_index, block_hash, call_txi, call_tx_hash, contract_pk) do
    shifted_events = events |> Enum.drop(1) |> Enum.concat([nil])

    # This function relies on a property that every Chain.clone and Chain.create
    # always have a subsequent Call.amount transaction which tranfers tokens
    # from the original contract to the newly created contract.
    {chain_events, non_chain_events} =
      events
      |> Enum.zip(shifted_events)
      |> Enum.split_with(fn
        {{{:internal_call_tx, "Chain.create"}, _info}, _next_event} -> true
        {{{:internal_call_tx, "Chain.clone"}, _info}, _next_event} -> true
        {{{:internal_call_tx, _fname}, _info}, _next_event} -> false
      end)

    chain_mutations =
      Enum.flat_map(chain_events, fn
        {{{:internal_call_tx, _fname}, _info}, next_event} ->
          {{:internal_call_tx, "Call.amount"}, %{info: aetx}} = next_event
          {:spend_tx, tx} = :aetx.specialize_type(aetx)
          recipient_id = :aec_spend_tx.recipient_id(tx)
          {:account, contract_pk} = :aeser_id.specialize(recipient_id)

          [
            aexn_create_contract_mutation(contract_pk, block_index, call_txi),
            ContractCreateCacheMutation.new(contract_pk, call_txi)
            | SyncOrigin.origin_mutations(
                :contract_call_tx,
                nil,
                contract_pk,
                call_txi,
                call_tx_hash
              )
          ]
      end)

    # Chain.* events don't contain the transaction in the event info, can't be indexed as an internal call
    int_calls =
      Enum.map(non_chain_events, fn {{{:internal_call_tx, fname}, %{info: tx}}, _next_event} ->
        {tx_type, raw_tx} = :aetx.specialize_type(tx)

        {fname, tx_type, tx, raw_tx}
      end)

    int_calls_mutation = IntCallsMutation.new(contract_pk, call_txi, int_calls)

    chain_mutations ++
      oracle_and_name_mutations(events, block_index, block_hash, call_txi) ++ [int_calls_mutation]
  end

  @spec aexn_create_contract_mutation(Db.pubkey(), Blocks.block_index(), Txs.txi()) ::
          nil | AexnCreateContractMutation.t()
  def aexn_create_contract_mutation(contract_pk, block_index, txi) do
    aexn_type =
      cond do
        AexnContracts.is_aex9?(contract_pk) -> :aex9
        AexnContracts.has_aex141_signatures?(contract_pk) -> :aex141
        true -> nil
      end

    with true <- aexn_type != nil,
         {:ok, aexn_extensions} <- AexnContracts.call_extensions(aexn_type, contract_pk),
         {:ok, aexn_meta_info} <- AexnContracts.call_meta_info(aexn_type, contract_pk) do
      if aexn_type == :aex9 or
           (aexn_type == :aex141 and
              AexnContracts.has_valid_aex141_extensions?(aexn_extensions, contract_pk)) do
        AexnCreateContractMutation.new(
          aexn_type,
          contract_pk,
          aexn_meta_info,
          block_index,
          txi,
          aexn_extensions
        )
      end
    else
      _false_or_notfound ->
        nil
    end
  end

  defp oracle_and_name_mutations(events, block_index, block_hash, call_txi) do
    events
    |> Enum.filter(fn
      {{:internal_call_tx, "Oracle.register"}, _info} -> true
      {{:internal_call_tx, "Oracle.respond"}, _info} -> true
      {{:internal_call_tx, "AENS.claim"}, _info} -> true
      {{:internal_call_tx, "AENS.update"}, _info} -> true
      {{:internal_call_tx, "AENS.transfer"}, _info} -> true
      {{:internal_call_tx, "AENS.revoke"}, _info} -> true
      _int_call -> false
    end)
    |> Enum.map(fn
      {{:internal_call_tx, "Oracle.register"}, %{info: aetx, tx_hash: tx_hash}} ->
        {:oracle_register_tx, tx} = :aetx.specialize_type(aetx)
        Oracle.register_mutations(tx, tx_hash, block_index, call_txi)

      {{:internal_call_tx, "Oracle.respond"}, %{info: aetx}} ->
        {:oracle_response_tx, tx} = :aetx.specialize_type(aetx)
        Oracle.response_mutation(tx, block_index, block_hash, call_txi)

      {{:internal_call_tx, "AENS.claim"}, %{info: aetx, tx_hash: tx_hash}} ->
        {:name_claim_tx, tx} = :aetx.specialize_type(aetx)
        Name.name_claim_mutations(tx, tx_hash, block_index, call_txi)

      {{:internal_call_tx, "AENS.update"}, %{info: aetx}} ->
        {:name_update_tx, tx} = :aetx.specialize_type(aetx)
        Name.update_mutations(tx, call_txi, block_index, true)

      {{:internal_call_tx, "AENS.transfer"}, %{info: aetx}} ->
        {:name_transfer_tx, tx} = :aetx.specialize_type(aetx)
        NameTransferMutation.new(tx, call_txi, block_index)

      {{:internal_call_tx, "AENS.revoke"}, %{info: aetx}} ->
        {:name_revoke_tx, tx} = :aetx.specialize_type(aetx)

        tx
        |> :aens_revoke_tx.name_hash()
        |> NameRevokeMutation.new(call_txi, block_index)
    end)
  end
end

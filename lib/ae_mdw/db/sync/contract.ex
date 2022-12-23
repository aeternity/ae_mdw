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
  alias AeMdw.Db.Sync.Oracle
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
  def child_contract_mutations({:error, _any}, _block_index, _txi_idx, _tx_hash), do: []

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
    shifted_events = [nil | events]

    # This function relies on a property that every Chain.clone and Chain.create
    # always have a previous Call.amount transaction which tranfers tokens
    # from the original contract to the newly created contract.
    {chain_events, non_chain_events} =
      shifted_events
      |> Enum.zip(events)
      |> Enum.split_with(fn
        {_prev_event, {{:internal_call_tx, "Chain.create"}, _info}} -> true
        {_prev_event, {{:internal_call_tx, "Chain.clone"}, _info}} -> true
        {_prev_event, {{:internal_call_tx, _fname}, _info}} -> false
      end)

    chain_mutations =
      Enum.flat_map(chain_events, fn
        {prev_event, {{:internal_call_tx, _fname}, _info}} ->
          {{:internal_call_tx, "Call.amount"}, %{info: aetx}} = prev_event
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
    # Oracle.query events don't have the right nonce (it's hard-coded to 0), which generates an invalid query_id
    int_calls =
      non_chain_events
      |> Enum.map(fn {_prev_event, {{:internal_call_tx, fname}, %{info: tx, tx_hash: tx_hash}}} ->
        {fname, tx, tx_hash}
      end)
      |> fix_oracle_queries(block_hash)
      |> Enum.with_index()
      |> Enum.map(fn {{fname, aetx, tx_hash}, local_idx} ->
        {tx_type, tx} = :aetx.specialize_type(aetx)

        {local_idx, fname, tx_type, aetx, tx, tx_hash}
      end)

    int_calls_mutation = IntCallsMutation.new(contract_pk, call_txi, int_calls)

    chain_mutations ++
      oracle_and_name_mutations(int_calls, block_index, call_txi) ++ [int_calls_mutation]
  end

  @spec aexn_create_contract_mutation(Db.pubkey(), Blocks.block_index(), Txs.txi()) ::
          nil | AexnCreateContractMutation.t()
  def aexn_create_contract_mutation(contract_pk, {height, _mbi} = block_index, txi) do
    aexn_type =
      cond do
        AexnContracts.is_aex9?(contract_pk) -> :aex9
        AexnContracts.has_aex141_signatures?(height, contract_pk) -> :aex141
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

  defp oracle_and_name_mutations(int_calls, {height, _mbi} = block_index, call_txi) do
    Enum.map(int_calls, fn
      {local_idx, "Oracle.extend", :oracle_extend_tx, _aetx, tx, _tx_hash} ->
        Oracle.extend_mutation(tx, block_index, {call_txi, local_idx})

      {local_idx, "Oracle.register", :oracle_register_tx, _aetx, tx, tx_hash} ->
        Oracle.register_mutations(tx, tx_hash, block_index, {call_txi, local_idx})

      {_local_idx, "Oracle.respond", :oracle_respond_tx, _aetx, tx, _tx_hash} ->
        Oracle.response_mutation(tx, block_index, call_txi)

      {_local_idx, "Oracle.query", :oracle_query_tx, _aetx, tx, _tx_hash} ->
        Oracle.query_mutation(tx, height)

      {local_idx, "AENS.claim", :name_claim_tx, _aetx, tx, tx_hash} ->
        Name.name_claim_mutations(tx, tx_hash, block_index, {call_txi, local_idx})

      {local_idx, "AENS.update", :name_update_tx, _aetx, tx, _tx_hash} ->
        Name.update_mutations(tx, {call_txi, local_idx}, block_index, true)

      {local_idx, "AENS.transfer", :name_transfer_tx, _aetx, tx, _tx_hash} ->
        NameTransferMutation.new(tx, {call_txi, local_idx}, block_index)

      {local_idx, "AENS.revoke", :name_revoke_tx, _aetx, tx, _tx_hash} ->
        tx
        |> :aens_revoke_tx.name_hash()
        |> NameRevokeMutation.new({call_txi, local_idx}, block_index)

      {_local_idx, _fname, _tx_type, _aetx, _tx, _tx_hash} ->
        []
    end)
  end

  # Temporary HACK to fix oracle query nonces.
  defp fix_oracle_queries(events, block_hash) do
    {fixed_events, _acc} =
      Enum.map_reduce(events, %{}, fn
        {"Oracle.query", aetx, tx_hash}, accounts_nonces ->
          {:oracle_query_tx, tx} = :aetx.specialize_type(aetx)
          sender_pk = :aeo_query_tx.sender_pubkey(tx)

          nonce =
            case Map.fetch(accounts_nonces, sender_pk) do
              {:ok, nonce} -> nonce
              :error -> Db.nonce_at_block(block_hash, sender_pk)
            end

          accounts_nonces = Map.put(accounts_nonces, sender_pk, nonce + 1)
          fixed_tx = put_elem(tx, 2, nonce)
          fixed_aetx = :aetx.update_tx(aetx, fixed_tx)

          {{"Oracle.query", fixed_aetx, tx_hash}, accounts_nonces}

        {fname, aetx, tx_hash}, accounts_nonces ->
          {{fname, aetx, tx_hash}, accounts_nonces}
      end)

    fixed_events
  end
end

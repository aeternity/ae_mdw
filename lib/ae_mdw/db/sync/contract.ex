defmodule AeMdw.Db.Sync.Contract do
  @moduledoc """
  Saves contract indexed state for creation, calls and events.
  """
  alias AeMdw.Blocks
  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.Model
  alias AeMdw.Db.TxnMutation
  alias AeMdw.Db.NameUpdateMutation
  alias AeMdw.Db.NameTransferMutation
  alias AeMdw.Db.NameRevokeMutation
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.Aex9CreateContractMutation
  alias AeMdw.Db.OracleRegisterMutation
  alias AeMdw.Db.Origin
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
        ) :: [TxnMutation.t()]
  def child_contract_mutations({:error, _any}, _block_index, _txi, _tx_hash), do: []

  def child_contract_mutations(%{result: fun_result}, block_index, txi, tx_hash) do
    with %{type: :contract, value: contract_id} <- fun_result,
         {:ok, contract_pk} <- Validate.id(contract_id) do
      :ets.insert(:ct_create_sync_cache, {contract_pk, txi})
      AeMdw.Ets.inc(:stat_sync_cache, :contracts_created)

      [
        aex9_create_contract_mutation(contract_pk, block_index, txi)
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
          Txs.txi()
        ) :: [
          TxnMutation.t()
        ]
  def events_mutations(events, block_index, block_hash, call_txi, call_tx_hash, create_txi) do
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
      Enum.map(chain_events, fn
        {{{:internal_call_tx, _fname}, _info}, next_event} ->
          {{:internal_call_tx, "Call.amount"}, %{info: aetx}} = next_event
          {:spend_tx, tx} = :aetx.specialize_type(aetx)
          recipient_id = :aec_spend_tx.recipient_id(tx)
          {:account, contract_pk} = :aeser_id.specialize(recipient_id)

          AeMdw.Ets.inc(:stat_sync_cache, :contracts_created)
          :ets.insert(:ct_create_sync_cache, {contract_pk, call_txi})

          [
            aex9_create_contract_mutation(contract_pk, block_index, call_txi)
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
    non_chain_mutations =
      non_chain_events
      |> Enum.with_index()
      |> Enum.flat_map(fn {{{{:internal_call_tx, fname}, %{info: tx}}, _next_event}, i} ->
        DBContract.int_call_write_mutations(create_txi, call_txi, i, fname, tx)
      end)

    chain_mutations ++
      oracle_and_name_mutations(events, block_index, block_hash, call_txi) ++ non_chain_mutations
  end

  @spec aex9_create_contract_mutation(Db.pubkey(), Blocks.block_index(), Txs.txi()) ::
          nil | Aex9CreateContractMutation.t()
  def aex9_create_contract_mutation(contract_pk, block_index, txi) do
    case Contract.is_aex9?(contract_pk) && Contract.aex9_meta_info(contract_pk) do
      {:ok, aex9_meta_info} ->
        Aex9CreateContractMutation.new(
          contract_pk,
          aex9_meta_info,
          block_index,
          txi
        )

      _false_or_notfound ->
        nil
    end
  end

  @spec get_txi!(Db.pubkey()) :: Txs.txi()
  def get_txi!(contract_pk) do
    case :ets.lookup(:ct_create_sync_cache, contract_pk) do
      [{^contract_pk, txi}] ->
        txi

      [] ->
        txi = Origin.tx_index!({:contract, contract_pk})

        :ets.insert(:ct_create_sync_cache, {contract_pk, txi})

        txi
    end
  end

  defp oracle_and_name_mutations(events, {height, _mbi} = block_index, block_hash, call_txi) do
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
      {{:internal_call_tx, "Oracle.register"}, %{info: aetx}} ->
        {:oracle_register_tx, tx} = :aetx.specialize_type(aetx)
        oracle_pk = :aeo_register_tx.account_pubkey(tx)
        delta_ttl = :aeo_utils.ttl_delta(height, :aeo_register_tx.oracle_ttl(tx))
        expire = height + delta_ttl

        OracleRegisterMutation.new(oracle_pk, block_index, expire, call_txi)

      {{:internal_call_tx, "Oracle.respond"}, %{info: aetx}} ->
        {:oracle_response_tx, tx} = :aetx.specialize_type(aetx)
        Oracle.response_mutation(tx, block_index, block_hash, call_txi)

      {{:internal_call_tx, "AENS.claim"}, %{info: aetx, tx_hash: tx_hash}} ->
        {:name_claim_tx, tx} = :aetx.specialize_type(aetx)
        Name.name_claim_mutations(tx, tx_hash, block_index, call_txi)

      {{:internal_call_tx, "AENS.update"}, %{info: aetx}} ->
        {:name_update_tx, tx} = :aetx.specialize_type(aetx)
        NameUpdateMutation.new(tx, call_txi, block_index, true)

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

defmodule AeMdw.Db.Sync.Contract do
  @moduledoc """
  Saves contract indexed state for creation, calls and events.
  """
  alias AeMdw.Blocks
  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.OracleRegisterMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.NameUpdateMutation
  alias AeMdw.Db.NameTransferMutation
  alias AeMdw.Db.NameRevokeMutation
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.OracleRegisterMutation
  alias AeMdw.Db.Origin
  alias AeMdw.Db.Sync.Origin, as: SyncOrigin
  alias AeMdw.Db.Sync.Name
  alias AeMdw.Node.Db
  alias AeMdw.Sync.AsyncTasks
  alias AeMdw.Txs
  alias AeMdw.Validate

  require Model

  @spec aex9_derive_account_presence!(tuple()) :: :ok
  def aex9_derive_account_presence!({kbi, mbi}) do
    ct_create? = fn
      {{_ct_pk, _txi, -1}, <<_::binary>>, -1} -> true
      {{_ct_pk, _txi, _}, {<<_::binary>>, <<_::binary>>}, _} -> false
    end

    :aex9_sync_cache
    |> :ets.tab2list()
    |> Enum.group_by(fn {{ct_pk, _, _}, _, _} -> ct_pk end)
    |> Enum.filter(fn {_ct_pk, [first_entry | _]} -> ct_create?.(first_entry) end)
    |> Enum.each(fn {ct_pk, [{{ct_pk, create_txi, -1}, <<_::binary>>, -1} | transfers]} ->
      recipients =
        transfers
        |> Enum.map(fn
          {{_ct_pk, _txi, _i}, {_from, to_pk}, _amount} -> to_pk
          _other -> nil
        end)
        |> Enum.reject(&is_nil/1)

      AsyncTasks.DeriveAex9Presence.cache_recipients(ct_pk, recipients)

      AsyncTasks.Producer.enqueue(:derive_aex9_presence, [ct_pk, kbi, mbi, create_txi])
    end)

    :ets.delete_all_objects(:aex9_sync_cache)

    :ok
  end

  @spec child_contract_mutations(
          boolean(),
          Contract.fun_arg_res_or_error(),
          Txs.txi(),
          Txs.tx_hash()
        ) ::
          {[Mutation.t()], Contract.aex9_meta_info() | nil}
  def child_contract_mutations(true = _call_rec_success, %{result: fun_result}, txi, tx_hash) do
    with %{type: :contract, value: contract_id} <- fun_result,
         {:ok, contract_pk} <- Validate.id(contract_id) do
      aex9_meta_info =
        case Contract.is_aex9?(contract_pk) && Contract.aex9_meta_info(contract_pk) do
          {:ok, aex9_meta_info} -> aex9_meta_info
          _false_or_notfound -> nil
        end

      :ets.insert(:ct_create_sync_cache, {contract_pk, txi})
      AeMdw.Ets.inc(:stat_sync_cache, :contracts)

      {
        SyncOrigin.origin_mutations(:contract_call_tx, nil, contract_pk, txi, tx_hash),
        aex9_meta_info
      }
    else
      _no_child_contract -> {[], nil}
    end
  end

  def child_contract_mutations(true = _call_rec_success, _error_fun_res, _txi, _tx_hash) do
    {[], nil}
  end

  def child_contract_mutations(false = _call_rec_success, _fun_res, _txi, _tx_hash) do
    {[], nil}
  end

  @spec events_mutations(
          [Contract.event()],
          Blocks.block_index(),
          Blocks.block_hash(),
          Txs.txi(),
          Txs.tx_hash(),
          Txs.txi()
        ) :: [
          Mutation.t()
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

          AeMdw.Ets.inc(:stat_sync_cache, :contracts)
          :ets.insert(:ct_create_sync_cache, {contract_pk, call_txi})

          SyncOrigin.origin_mutations(:contract_call_tx, nil, contract_pk, call_txi, call_tx_hash)
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

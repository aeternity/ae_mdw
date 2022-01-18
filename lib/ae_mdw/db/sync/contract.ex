defmodule AeMdw.Db.Sync.Contract do
  @moduledoc """
  Saves contract indexed state for creation, calls and events.
  """
  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.MnesiaWriteMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.NameUpdateMutation
  alias AeMdw.Db.NameTransferMutation
  alias AeMdw.Db.NameRevokeMutation
  alias AeMdw.Db.OracleRegisterMutation
  alias AeMdw.Db.Origin
  alias AeMdw.Db.Sync.Name
  alias AeMdw.Node.Db
  alias AeMdw.Sync.AsyncTasks
  alias AeMdw.Txs

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

  @spec events_mutations([Contract.event()], Blocks.block_index(), Txs.txi(), Txs.txi()) :: [
          Mutation.t()
        ]
  def events_mutations(events, block_index, call_txi, create_txi) do
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
          {:account, contract_id} = :aeser_id.specialize(recipient_id)
          m_field = Model.field(index: {:contract_call_tx, nil, contract_id, call_txi})
          MnesiaWriteMutation.new(Model.Field, m_field)
      end)

    # Chain.* events don't contain the transaction in the event info, can't be indexed as an internal call
    non_chain_mutations =
      non_chain_events
      |> Enum.with_index()
      |> Enum.flat_map(fn {{{{:internal_call_tx, fname}, %{info: tx}}, _next_event}, i} ->
        DBContract.int_call_write_mutations(create_txi, call_txi, i, fname, tx)
      end)

    chain_mutations ++
      oracle_and_name_mutations(events, block_index, call_txi) ++ non_chain_mutations
  end

  @spec get_txi(Db.pubkey()) :: integer()
  def get_txi(contract_pk) do
    case :ets.lookup(:ct_create_sync_cache, contract_pk) do
      [{^contract_pk, txi}] ->
        txi

      [] ->
        case Origin.tx_index({:contract, contract_pk}) do
          nil ->
            -1

          txi ->
            :ets.insert(:ct_create_sync_cache, {contract_pk, txi})
            txi
        end
    end
  end

  defp oracle_and_name_mutations(events, {height, _mbi} = block_index, call_txi) do
    events
    |> Enum.filter(fn
      {{:internal_call_tx, "Oracle.register"}, _info} -> true
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

      {{:internal_call_tx, "AENS.claim"}, %{info: aetx, tx_hash: tx_hash}} ->
        {:name_claim_tx, tx} = :aetx.specialize_type(aetx)
        Name.name_claim_mutations(tx, tx_hash, block_index, call_txi)

      {{:internal_call_tx, "AENS.update"}, %{info: aetx}} ->
        {:name_update_tx, tx} = :aetx.specialize_type(aetx)
        NameUpdateMutation.new(tx, call_txi, block_index)

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

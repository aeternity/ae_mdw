defmodule AeMdw.Db.Sync.Contract do
  @moduledoc """
  Saves contract indexed state for creation, calls and events.
  """
  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.MnesiaWriteMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.Origin
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

  @spec events_mutations([Contract.event()], Txs.txi(), Txs.txi()) :: [Mutation.t()]
  def events_mutations(events, call_txi, create_txi) do
    shifted_events = events |> Enum.drop(1) |> Enum.concat([nil])

    # This function relies on a property that every Chain.clone and Chain.create
    # always have a subsequent Call.amount transaction which tranfers tokens
    # from the original contract to the newly created contract.
    chain_mutations =
      events
      |> Enum.zip(shifted_events)
      |> Enum.filter(fn
        {{{:internal_call_tx, "Chain.create"}, _info}, _next_event} -> true
        {{{:internal_call_tx, "Chain.clone"}, _info}, _next_event} -> true
        {{{:internal_call_tx, _fname}, _info}, _next_event} -> false
      end)
      |> Enum.map(fn
        {{{:internal_call_tx, _fname}, _info}, next_event} ->
          {{:internal_call_tx, "Call.amount"}, %{info: aetx}} = next_event
          {:spend_tx, tx} = :aetx.specialize_type(aetx)
          recipient_id = :aec_spend_tx.recipient_id(tx)
          {:account, contract_id} = :aeser_id.specialize(recipient_id)
          m_field = Model.field(index: {:contract_call_tx, nil, contract_id, call_txi})
          MnesiaWriteMutation.new(Model.Field, m_field)
      end)

    int_calls_mutations =
      events
      |> Enum.with_index()
      |> Enum.flat_map(fn {{{:internal_call_tx, fname}, %{info: tx}}, i} ->
        DBContract.int_call_write_mutations(create_txi, call_txi, i, fname, tx)
      end)

    chain_mutations ++ int_calls_mutations
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
end

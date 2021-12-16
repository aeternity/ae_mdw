defmodule AeMdw.Db.Sync.Contract do
  @moduledoc """
  Saves contract indexed state for creation, calls and events.
  """
  alias AeMdw.Blocks
  alias AeMdw.Contract
  alias AeMdw.Db
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.Model
  alias AeMdw.Sync.AsyncTasks

  require Model

  @typep pubkey() :: DBContract.pubkey()

  @spec create(pubkey(), pubkey(), tuple(), integer(), Blocks.key_hash()) ::
          term() | :invalid_contract
  def create(contract_pk, owner_pk, tx, txi, block_hash) do
    case Contract.get_info(contract_pk) do
      {:ok, contract_info} ->
        with true <- Contract.is_aex9?(contract_info) do
          contract_pk
          |> Contract.aex9_meta_info()
          |> DBContract.aex9_creation_write(contract_pk, owner_pk, txi)
        end

        AeMdw.Ets.inc(:stat_sync_cache, :contracts)

        call_rec = Contract.get_init_call_rec(contract_pk, tx, block_hash)

        DBContract.logs_write(txi, txi, call_rec)

      {:error, _reason} ->
        :invalid_contract
    end
  end

  @spec call(pubkey(), tuple(), integer(), Blocks.block_hash()) :: :ok
  def call(contract_pk, tx, txi, block_hash) do
    create_txi = get_txi(contract_pk)

    {fun_arg_res, call_rec} =
      Contract.call_tx_info(tx, contract_pk, block_hash, &Contract.to_map/1)

    DBContract.call_write(create_txi, txi, fun_arg_res)
    DBContract.logs_write(create_txi, txi, call_rec)

    :ok
  end

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

  @spec events([Contract.event()], integer(), integer()) :: :ok
  def events(events, call_txi, create_txi) do
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

    Enum.each(chain_events, fn
      {{{:internal_call_tx, _fname}, _info}, next_event} ->
        {{:internal_call_tx, "Call.amount"}, %{info: aetx}} = next_event
        {:spend_tx, tx} = :aetx.specialize_type(aetx)
        recipient_id = :aec_spend_tx.recipient_id(tx)
        {:account, contract_id} = :aeser_id.specialize(recipient_id)
        m_field = Model.field(index: {:contract_call_tx, nil, contract_id, call_txi})
        :mnesia.write(Model.Field, m_field, :write)
    end)

    non_chain_events
    |> Enum.with_index()
    |> Enum.each(fn {{{{:internal_call_tx, fname}, %{info: tx}}, _next_event}, i} ->
      DBContract.int_call_write(create_txi, call_txi, i, fname, tx)
    end)
  end

  @spec get_txi(pubkey()) :: integer()
  def get_txi(contract_pk) do
    case :ets.lookup(:ct_create_sync_cache, contract_pk) do
      [{^contract_pk, txi}] ->
        txi

      [] ->
        case Db.Origin.tx_index({:contract, contract_pk}) do
          nil ->
            -1

          txi ->
            :ets.insert(:ct_create_sync_cache, {contract_pk, txi})
            txi
        end
    end
  end
end

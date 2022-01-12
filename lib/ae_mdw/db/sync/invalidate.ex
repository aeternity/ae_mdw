defmodule AeMdw.Db.Sync.Invalidate do
  alias AeMdw.Contract
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync
  alias AeMdw.Log
  alias AeMdw.Node, as: AE
  alias AeMdw.Validate

  require Model

  import AeMdw.Util
  import AeMdw.Db.Util

  ##########

  def invalidate(fork_height) when is_integer(fork_height) do
    prev_kbi = fork_height - 1
    from_txi = Model.block(read_block!({prev_kbi, -1}), :tx_index)

    cond do
      is_integer(from_txi) && from_txi >= 0 ->
        Log.info("invalidating from tx #{from_txi} at generation #{prev_kbi}")
        bi_keys = block_keys_range({prev_kbi, 0})
        {tx_keys, id_counts} = tx_keys_range(from_txi)

        stat_key_dels = stat_key_dels(prev_kbi)

        contract_log_key_dels = contract_log_key_dels(from_txi)
        contract_call_key_dels = contract_call_key_dels(from_txi)

        aex9_key_dels = aex9_key_dels(from_txi)
        aex9_transfer_key_dels = aex9_transfer_key_dels(from_txi)
        aex9_account_presence_key_dels = aex9_account_presence_key_dels(from_txi)
        aex9_account_presence_key_writes = aex9_account_presence_key_writes(from_txi)

        int_contract_call_key_dels = int_contract_call_key_dels(from_txi)
        int_transfer_tx_key_dels = int_transfer_tx_key_dels(prev_kbi)

        tab_keys = Map.merge(bi_keys, tx_keys)

        :mnesia.transaction(fn ->
          {name_dels, name_writes} = Sync.Name.invalidate(fork_height - 1)
          {oracle_dels, oracle_writes} = Sync.OracleInvalidation.invalidate(fork_height - 1)

          do_dels(tab_keys)
          do_dels(stat_key_dels)
          do_dels(name_dels, &AeMdw.Db.Name.cache_through_delete/2)
          do_dels(oracle_dels, &AeMdw.Db.Oracle.cache_through_delete/2)

          do_dels(aex9_key_dels)
          do_dels(aex9_transfer_key_dels)
          do_dels(aex9_account_presence_key_dels)
          do_dels(contract_log_key_dels)
          do_dels(contract_call_key_dels)

          do_dels(int_contract_call_key_dels)
          do_dels(int_transfer_tx_key_dels)

          do_writes(name_writes, &AeMdw.Db.Name.cache_through_write/2)
          do_writes(oracle_writes, &AeMdw.Db.Oracle.cache_through_write/2)

          do_writes(
            aex9_account_presence_key_writes,
            &AeMdw.Db.Contract.aex9_presence_cache_write/2
          )

          Enum.each(id_counts, fn {f_key, delta} -> Model.update_count(f_key, -delta) end)
        end)

      # wasn't synced up to that txi, nothing to do
      true ->
        :ok
    end
  end

  ################################################################################
  # Invalidations - keys for records to delete in case of fork

  def block_keys_range({_, _} = from_bi),
    do: %{
      Model.Block =>
        collect_keys(Model.Block, [from_bi], from_bi, &:mnesia.next/2, &{:cont, [&1 | &2]})
    }

  def stat_key_dels(from_kbi) do
    keys = from_kbi..last_gen()
    %{Model.Stat => keys, Model.SumStat => keys}
  end

  def tx_keys_range(from_txi),
    do: tx_keys_range(from_txi, last(Model.Tx))

  def tx_keys_range(from_txi, to_txi) when from_txi > to_txi,
    do: %{}

  def tx_keys_range(from_txi, to_txi) when from_txi <= to_txi do
    tx_keys = Enum.to_list(from_txi..to_txi)

    {type_keys, field_keys, field_counts} = type_fields_keys(tx_keys)

    time_keys = time_keys_range(from_txi, to_txi)
    {origin_keys, rev_origin_keys} = origin_keys_range(from_txi, to_txi)

    {%{
       Model.Tx => tx_keys,
       Model.Type => type_keys,
       Model.Time => time_keys,
       Model.Field => field_keys,
       Model.Origin => origin_keys,
       Model.RevOrigin => rev_origin_keys
     }, %{Model.IdCount => field_counts}}
  end

  def type_fields_keys(txis) do
    Enum.reduce(txis, {[], [], %{}}, fn txi, {type_keys, field_keys, field_counts} ->
      %{tx: %{type: tx_type} = tx, hash: tx_hash} = Format.to_raw_map(read_tx!(txi))

      {fields, f_counts} =
        for {id_key, pos} <- AE.tx_ids(tx_type), reduce: {[], field_counts} do
          {fxs, fcs} ->
            pk = pk(tx[id_key])
            {[{tx_type, pos, pk, txi} | fxs], Map.update(fcs, {tx_type, pos, pk}, 1, &(&1 + 1))}
        end

      {fields, f_counts} =
        case link_del_keys(tx_type, tx_hash, txi) do
          {link_key_txi, link_key_count} ->
            {[link_key_txi | fields], Map.update(f_counts, link_key_count, 1, &(&1 + 1))}

          nil ->
            {fields, f_counts}
        end

      {[{tx_type, txi} | type_keys], fields ++ field_keys, f_counts}
    end)
  end

  def link_del_keys(tx_type, tx_hash, txi) do
    with pk = <<_::binary>> <- link_del_pubkey(tx_type, tx_hash) do
      link_key = {tx_type, nil, pk, txi}
      incr_key = {tx_type, nil, pk}
      {link_key, incr_key}
    end
  end

  def link_del_pubkey(:contract_create_tx, tx_hash),
    do: :aect_contracts.pubkey(:aect_contracts.new(AE.Db.get_tx(tx_hash)))

  def link_del_pubkey(:channel_create_tx, tx_hash),
    do: ok!(:aesc_utils.channel_pubkey(AE.Db.get_signed_tx(tx_hash)))

  def link_del_pubkey(:oracle_register_tx, tx_hash),
    do: :aeo_register_tx.account_pubkey(AE.Db.get_tx(tx_hash))

  def link_del_pubkey(:name_claim_tx, tx_hash),
    do: ok!(:aens.get_name_hash(:aens_claim_tx.name(AE.Db.get_tx(tx_hash))))

  def link_del_pubkey(_type, _tx_hash),
    do: nil

  def time_keys_range(from_txi, to_txi) do
    bi_time = fn bi ->
      Model.block(read!(Model.Block, bi), :hash)
      |> :aec_db.get_header()
      |> :aec_headers.time_in_msecs()
    end

    from_bi = Model.tx(read_tx!(from_txi), :block_index)

    folder = fn tx, {bi, time, acc} ->
      case Model.tx(tx, :block_index) do
        ^bi ->
          {bi, time, [{time, Model.tx(tx, :index)} | acc]}

        new_bi ->
          new_time = bi_time.(new_bi)
          {new_bi, new_time, [{new_time, Model.tx(tx, :index)} | acc]}
      end
    end

    {_, _, keys} =
      DBS.map(from_txi..to_txi, & &1)
      |> Enum.reduce({from_bi, bi_time.(from_bi), []}, folder)

    keys
  end

  def origin_keys_range(from_txi, to_txi) do
    case :mnesia.dirty_next(Model.RevOrigin, {from_txi, :_, nil}) do
      :"$end_of_table" ->
        {[], []}

      start_key ->
        push_key = fn {txi, pk_type, pk}, {origins, rev_origins} ->
          {[{pk_type, pk, txi} | origins], [{txi, pk_type, pk} | rev_origins]}
        end

        collect_keys(Model.RevOrigin, push_key.(start_key, {[], []}), start_key, &next/2, fn
          {txi, pk_type, pk}, acc when txi <= to_txi ->
            {:cont, push_key.({txi, pk_type, pk}, acc)}

          {txi, _, _}, acc when txi > to_txi ->
            {:halt, acc}
        end)
    end
  end

  def aex9_key_dels(from_txi) do
    {aex9_keys, aex9_sym_keys, aex9_rev_keys} =
      case :mnesia.dirty_next(Model.RevAex9Contract, {from_txi, nil, nil, nil}) do
        :"$end_of_table" ->
          {[], [], []}

        start_key ->
          push_key = fn {txi, name, symbol, decimals}, {contracts, symbols, rev_contracts} ->
            {[{name, symbol, txi, decimals} | contracts],
             [{symbol, name, txi, decimals} | symbols],
             [{txi, name, symbol, decimals} | rev_contracts]}
          end

          collect_keys(
            Model.RevAex9Contract,
            push_key.(start_key, {[], [], []}),
            start_key,
            &next/2,
            fn key, acc -> {:cont, push_key.(key, acc)} end
          )
      end

    %{
      Model.Aex9Contract => aex9_keys,
      Model.Aex9ContractSymbol => aex9_sym_keys,
      Model.RevAex9Contract => aex9_rev_keys
    }
  end

  def aex9_transfer_key_dels(from_txi) do
    {aex9_tr_keys, aex9_rev_tr_keys, aex9_idx_tr_keys} =
      case :mnesia.dirty_next(Model.IdxAex9Transfer, {from_txi, 0, nil, nil, 0}) do
        :"$end_of_table" ->
          {[], [], []}

        start_key ->
          push_key = fn {txi, log_idx, from_pk, to_pk, amount}, {tr_keys, rev_keys, idx_keys} ->
            tr_key = {from_pk, to_pk, amount, txi, log_idx}
            rev_key = {to_pk, from_pk, amount, txi, log_idx}
            idx_key = {txi, log_idx, from_pk, to_pk, amount}
            {[tr_key | tr_keys], [rev_key | rev_keys], [idx_key | idx_keys]}
          end

          collect_keys(
            Model.IdxAex9Transfer,
            push_key.(start_key, {[], [], []}),
            start_key,
            &next/2,
            fn key, acc -> {:cont, push_key.(key, acc)} end
          )
      end

    %{
      Model.Aex9Transfer => aex9_tr_keys,
      Model.RevAex9Transfer => aex9_rev_tr_keys,
      Model.IdxAex9Transfer => aex9_idx_tr_keys
    }
  end

  def aex9_account_presence_key_dels(from_txi) do
    {aex9_presence_keys, idx_aex9_presence_keys} =
      case :mnesia.dirty_next(Model.IdxAex9AccountPresence, {from_txi, nil, nil}) do
        :"$end_of_table" ->
          {[], []}

        start_key ->
          push_key = fn {txi, acc_pk, ct_pk}, {acc_keys, idx_keys} ->
            acc_key = {acc_pk, txi, ct_pk}
            idx_key = {txi, acc_pk, ct_pk}
            {[acc_key | acc_keys], [idx_key | idx_keys]}
          end

          collect_keys(
            Model.IdxAex9AccountPresence,
            push_key.(start_key, {[], []}),
            start_key,
            &next/2,
            fn key, acc -> {:cont, push_key.(key, acc)} end
          )
      end

    %{
      Model.Aex9AccountPresence => aex9_presence_keys,
      Model.IdxAex9AccountPresence => idx_aex9_presence_keys
    }
  end

  # computes records to be written to cache, flushed at microblock boundary
  def aex9_account_presence_key_writes(from_txi) do
    bi = Model.tx(read_tx!(from_txi), :block_index)
    start_txi = Model.block(read_block!(bi), :tx_index)
    end_txi = from_txi - 1

    cond do
      start_txi <= end_txi ->
        scope = {:txi, start_txi..end_txi}

        creates =
          scope
          |> DBS.map(:raw, type: :contract_create)
          |> Stream.map(fn %{} = x ->
            ct_pk = Validate.id!(x.tx.contract_id)

            if Contract.is_aex9?(ct_pk) do
              {{ct_pk, x.tx_index, -1}, Validate.id!(x.tx.owner_id), -1}
            else
              nil
            end
          end)
          |> Stream.filter(& &1)
          |> Enum.to_list()

        transfer_evt = AeMdw.Node.aex9_transfer_event_hash()

        contract_calls = fn contract_pk ->
          scope
          |> DBS.map(:raw, type: :contract_call, contract_id: contract_pk)
          |> Enum.flat_map(fn %{tx: %{log: logs}} = x ->
            idxed_logs = Enum.with_index(logs)

            for {%{topics: [^transfer_evt, from_pk, to_pk, <<amount::256>>]}, i} <- idxed_logs,
                do: {{contract_pk, x.tx_index, i}, {from_pk, to_pk}, amount}
          end)
        end

        calls = Enum.flat_map(creates, fn {{ct_pk, _, _}, _, _} -> contract_calls.(ct_pk) end)

        %{:aex9_sync_cache => creates ++ calls}

      true ->
        %{}
    end
  end

  def contract_log_key_dels(from_txi) do
    {log_keys, data_log_keys, evt_log_keys, idx_log_keys} =
      case :mnesia.dirty_next(Model.IdxContractLog, {from_txi, 0, nil, 0}) do
        :"$end_of_table" ->
          {[], [], [], []}

        start_key ->
          push_key = fn {call_txi, create_txi, evt_hash, log_idx},
                        {log_keys, data_keys, evt_keys, idx_keys} ->
            log_key = {create_txi, call_txi, log_idx, evt_hash}
            evt_key = {evt_hash, create_txi, call_txi, log_idx}
            idx_key = {call_txi, create_txi, evt_hash, log_idx}

            m_log = read!(Model.ContractLog, log_key)
            data = Model.contract_log(m_log, :data)
            data_key = {data, create_txi, evt_hash, call_txi, log_idx}

            {[log_key | log_keys], [data_key | data_keys], [evt_key | evt_keys],
             [idx_key | idx_keys]}
          end

          collect_keys(
            Model.IdxContractLog,
            push_key.(start_key, {[], [], [], []}),
            start_key,
            &next/2,
            fn key, acc -> {:cont, push_key.(key, acc)} end
          )
      end

    %{
      Model.ContractLog => log_keys,
      Model.DataContractLog => data_log_keys,
      Model.EvtContractLog => evt_log_keys,
      Model.IdxContractLog => idx_log_keys
    }
  end

  def contract_call_key_dels(from_txi) do
    contract_call_keys =
      case :mnesia.dirty_next(Model.ContractCall, {from_txi, 0}) do
        :"$end_of_table" ->
          []

        start_key ->
          collect_keys(
            Model.ContractCall,
            [start_key],
            start_key,
            &next/2,
            fn key, acc -> {:cont, [key | acc]} end
          )
      end

    %{Model.ContractCall => contract_call_keys}
  end

  def int_contract_call_key_dels(from_txi) do
    {int_keys, grp_keys, fname_keys, fname_grp_keys, id_keys, grp_id_keys, id_fname_keys,
     grp_id_fname_keys} =
      case :mnesia.dirty_next(Model.IntContractCall, {from_txi, -1}) do
        :"$end_of_table" ->
          {[], [], [], [], [], [], [], []}

        start_key ->
          push_key = fn {call_txi, local_idx},
                        {int_keys, grp_keys, fname_keys, fname_grp_keys, id_keys, grp_id_keys,
                         id_fname_keys, grp_id_fname_keys} ->
            int_key = {call_txi, local_idx}

            m_int_call = read!(Model.IntContractCall, int_key)
            create_txi = Model.int_contract_call(m_int_call, :create_txi)
            fname = Model.int_contract_call(m_int_call, :fname)

            grp_key = {create_txi, call_txi, local_idx}
            fname_key = {fname, call_txi, local_idx}
            fname_grp_key = {fname, create_txi, call_txi, local_idx}

            {tx_type, raw_tx} =
              m_int_call
              |> Model.int_contract_call(:tx)
              |> :aetx.specialize_type()

            {id_keys0, grp_id_keys0, id_fname_keys0, grp_id_fname_keys0} =
              for {_, pos} <- AE.tx_ids(tx_type), reduce: {[], [], [], []} do
                {id_keys0, grp_id_keys0, id_fname_keys0, grp_id_fname_keys0} ->
                  pk = Validate.id!(elem(raw_tx, pos))

                  {[{pk, pos, call_txi, local_idx} | id_keys0],
                   [{create_txi, pk, pos, call_txi, local_idx} | grp_id_keys0],
                   [{pk, fname, pos, call_txi, local_idx} | id_fname_keys0],
                   [{create_txi, pk, fname, pos, call_txi, local_idx} | grp_id_fname_keys0]}
              end

            {[int_key | int_keys], [grp_key | grp_keys], [fname_key | fname_keys],
             [fname_grp_key | fname_grp_keys], Enum.concat(id_keys0, id_keys),
             Enum.concat(grp_id_keys0, grp_id_keys), Enum.concat(id_fname_keys0, id_fname_keys),
             Enum.concat(grp_id_fname_keys0, grp_id_fname_keys)}
          end

          collect_keys(
            Model.IntContractCall,
            push_key.(start_key, {[], [], [], [], [], [], [], []}),
            start_key,
            &next/2,
            fn key, acc -> {:cont, push_key.(key, acc)} end
          )
      end

    %{
      Model.IntContractCall => int_keys,
      Model.GrpIntContractCall => grp_keys,
      Model.FnameIntContractCall => fname_keys,
      Model.FnameGrpIntContractCall => fname_grp_keys,
      Model.IdIntContractCall => id_keys,
      Model.GrpIdIntContractCall => grp_id_keys,
      Model.IdFnameIntContractCall => id_fname_keys,
      Model.GrpIdFnameIntContractCall => grp_id_fname_keys
    }
  end

  def int_transfer_tx_key_dels(prev_kbi) do
    {int_keys, kind_keys, target_keys} =
      case :mnesia.dirty_next(Model.IntTransferTx, {prev_kbi, -2}) do
        :"$end_of_table" ->
          {[], [], []}

        start_key ->
          push_key = fn {location, kind, target_pk, ref_txi},
                        {int_keys, kind_keys, target_keys} ->
            {[{location, kind, target_pk, ref_txi} | int_keys],
             [{kind, location, target_pk, ref_txi} | kind_keys],
             [{target_pk, location, kind, ref_txi} | target_keys]}
          end

          collect_keys(
            Model.IntTransferTx,
            push_key.(start_key, {[], [], []}),
            start_key,
            &next/2,
            fn key, acc -> {:cont, push_key.(key, acc)} end
          )
      end

    %{
      Model.IntTransferTx => int_keys,
      Model.KindIntTransferTx => kind_keys,
      Model.TargetIntTransferTx => target_keys
    }
  end

  ##########

  defp pk({:id, _, _} = id) do
    {_, pk} = :aeser_id.specialize(id)
    pk
  end

  # defp log_del_keys(tab_keys) do
  #   {blocks, tab_keys} = Map.pop(tab_keys, ~t[block])
  #   {txs, tab_keys} = Map.pop(tab_keys, ~t[tx])
  #   [b_count, t_count] = [blocks, txs] |> Enum.map(&Enum.count/1)
  #   {b1, b2} = {List.last(blocks), List.first(blocks)}
  #   {t1, t2} = {List.first(txs), List.last(txs)}
  #   Log.info("table block has #{b_count} records to delete: #{inspect(b1)}..#{inspect(b2)}")
  #   Log.info("table tx has #{t_count} records to delete: #{t1}..#{t2}")
  #   for {tab, keys} <- tab_keys,
  #       do: Log.info("table #{Model.record(tab)} has #{Enum.count(keys)} records to delete")
  #   :ok
  # end
end

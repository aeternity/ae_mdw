defmodule AeMdw.Db.Contract do
  alias AeMdw.Node, as: AE
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.{Log, Validate}

  require Record
  require Model
  require Log

  import AeMdw.Util, only: [compose: 2]
  import AeMdw.Db.Util

  ##########

  def aex9_creation_write({name, symbol, decimals}, contract_pk, owner_pk, txi) do
    m_contract = Model.aex9_contract(index: {name, symbol, txi, decimals})
    m_contract_sym = Model.aex9_contract_symbol(index: {symbol, name, txi, decimals})
    m_rev_contract = Model.rev_aex9_contract(index: {txi, name, symbol, decimals})
    m_contract_pk = Model.aex9_contract_pubkey(index: contract_pk, txi: txi)
    :mnesia.write(Model.Aex9Contract, m_contract, :write)
    :mnesia.write(Model.Aex9ContractSymbol, m_contract_sym, :write)
    :mnesia.write(Model.RevAex9Contract, m_rev_contract, :write)
    :mnesia.write(Model.Aex9ContractPubkey, m_contract_pk, :write)

    aex9_presence_cache_write({{contract_pk, txi, -1}, owner_pk, -1})
  end

  def aex9_write_presence(contract_pk, txi, pubkey) do
    m_acc_presence = Model.aex9_account_presence(index: {pubkey, txi, contract_pk})
    m_idx_presence = Model.idx_aex9_account_presence(index: {txi, pubkey, contract_pk})
    :mnesia.write(Model.Aex9AccountPresence, m_acc_presence, :write)
    :mnesia.write(Model.IdxAex9AccountPresence, m_idx_presence, :write)
  end

  def call_write(create_txi, txi, %{function: fname, arguments: args, result: %{error: [err]}}),
    do: call_write(create_txi, txi, fname, args, :error, err)

  def call_write(create_txi, txi, %{function: fname, arguments: args, result: %{abort: [err]}}),
    do: call_write(create_txi, txi, fname, args, :abort, err)

  def call_write(create_txi, txi, %{function: fname, arguments: args, result: val}),
    do: call_write(create_txi, txi, fname, args, :ok, val)

  def call_write(create_txi, txi, {:error, detail}),
    do: call_write(create_txi, txi, "<unknown>", nil, :invalid, inspect(detail))

  def call_write(create_txi, txi, fname, args, result, return) do
    m_call =
      Model.contract_call(
        index: {create_txi, txi},
        fun: fname,
        args: args,
        result: result,
        return: return
      )

    :mnesia.write(Model.ContractCall, m_call, :write)
  end

  def logs_write(create_txi, txi, call_rec) do
    contract_pk = :aect_call.contract_pubkey(call_rec)
    raw_logs = :aect_call.log(call_rec)

    raw_logs
    |> Enum.with_index()
    |> Enum.each(fn {{addr, [evt_hash | args], data}, i} ->
      m_log =
        Model.contract_log(
          index: {create_txi, txi, evt_hash, i},
          ext_contract: (addr == contract_pk && nil) || addr,
          args: args,
          data: data
        )

      # if remote call then indexes also with the called contract
      if addr != contract_pk do
        remote_called_contract_txi = Origin.tx_index({:contract, addr})

        # ext_contract is nil because it's a field for the called contract not the remote caller
        # (nil also indicates it's a remote/indirect call as for regular calls ext_contract = contract_pk)
        m_log_remote =
          Model.contract_log(
            index: {remote_called_contract_txi, txi, evt_hash, i},
            ext_contract: nil,
            args: args,
            data: data
          )
        :mnesia.write(Model.ContractLog, m_log_remote, :write)
      end

      m_data_log = Model.data_contract_log(index: {data, txi, create_txi, evt_hash, i})
      m_evt_log = Model.evt_contract_log(index: {evt_hash, txi, create_txi, i})
      m_idx_log = Model.idx_contract_log(index: {txi, create_txi, evt_hash, i})
      :mnesia.write(Model.ContractLog, m_log, :write)
      :mnesia.write(Model.DataContractLog, m_data_log, :write)
      :mnesia.write(Model.EvtContractLog, m_evt_log, :write)
      :mnesia.write(Model.IdxContractLog, m_idx_log, :write)
    end)

    case AeMdw.Contract.is_aex9?(contract_pk) do
      true ->
        transfer_evt = AeMdw.Node.aex9_transfer_event_hash()

        raw_logs
        |> Enum.with_index()
        |> Enum.each(fn
          {{_addr, [^transfer_evt, from_pk, to_pk, <<amount::256>>], ""}, i} ->
            m_transfer = Model.aex9_transfer(index: {from_pk, to_pk, amount, txi, i})
            m_rev_transfer = Model.rev_aex9_transfer(index: {to_pk, from_pk, amount, txi, i})
            m_idx_transfer = Model.idx_aex9_transfer(index: {txi, i, from_pk, to_pk, amount})
            :mnesia.write(Model.Aex9Transfer, m_transfer, :write)
            :mnesia.write(Model.RevAex9Transfer, m_rev_transfer, :write)
            :mnesia.write(Model.IdxAex9Transfer, m_idx_transfer, :write)
            aex9_write_presence(contract_pk, txi, to_pk)

            aex9_presence_cache_write({{contract_pk, txi, i}, {from_pk, to_pk}, amount})

          {_, _} ->
            :ok
        end)

      false ->
        nil
    end
  end

  def call_fun_args_res(contract_pk, call_txi) do
    create_txi =
      (contract_pk == AeMdw.Db.Sync.Contract.migrate_contract_pk() &&
         -1) || AeMdw.Db.Origin.tx_index({:contract, contract_pk})

    m_call = read!(Model.ContractCall, {create_txi, call_txi})

    %{
      function: Model.contract_call(m_call, :fun),
      arguments: Model.contract_call(m_call, :args),
      result: Model.contract_call(m_call, :result),
      return: Model.contract_call(m_call, :return)
    }
  end

  def prefix_tester(""),
    do: fn _ -> true end

  def prefix_tester(prefix) do
    len = byte_size(prefix)
    &(byte_size(&1) >= len && :binary.part(&1, 0, len) == prefix)
  end

  def aex9_search_name({_, _} = mode),
    do: aex9_search_tokens(Model.Aex9Contract, mode)

  def aex9_search_symbol({_, _} = mode),
    do: aex9_search_tokens(Model.Aex9ContractSymbol, mode)

  def aex9_search_tokens(table, {:prefix, prefix}),
    do: aex9_search_tokens(table, prefix, prefix_tester(prefix))

  def aex9_search_tokens(table, {:exact, exact}),
    do: aex9_search_tokens(table, exact, &(&1 == exact))

  def aex9_search_tokens(table, value, key_tester) do
    gen_collect(
      table,
      {value, "", 0, 0},
      compose(key_tester, &elem(&1, 0)),
      &next/2,
      fn -> [] end,
      fn v, l -> [v | l] end,
      &Enum.reverse/1
    )
  end

  def aex9_search_transfers({:from, sender_pk}) do
    aex9_search_transfers(
      Model.Aex9Transfer,
      {sender_pk, nil, 0, 0, 0},
      fn key -> elem(key, 0) == sender_pk end
    )
  end

  def aex9_search_transfers({:to, recipient_pk}) do
    aex9_search_transfers(
      Model.RevAex9Transfer,
      {recipient_pk, nil, 0, 0, 0},
      fn key -> elem(key, 0) == recipient_pk end
    )
  end

  def aex9_search_transfers({:from_to, sender_pk, recipient_pk}) do
    aex9_search_transfers(
      Model.Aex9Transfer,
      {sender_pk, recipient_pk, 0, 0, 0},
      fn {s, r, _, _, _} -> s == sender_pk && r == recipient_pk end
    )
  end

  def aex9_search_transfers(table, init_key, key_tester) do
    gen_collect(
      table,
      init_key,
      key_tester,
      &next/2,
      fn -> [] end,
      fn v, l -> [v | l] end,
      &Enum.reverse/1
    )
  end

  def aex9_search_contract(account_pk, last_txi) do
    gen_collect(
      Model.Aex9AccountPresence,
      {account_pk, last_txi, <<AeMdw.Util.max_256bit_int()::256>>},
      fn {acc_pk, _, _} -> acc_pk == account_pk end,
      &prev/2,
      fn -> %{} end,
      fn {_, txi, ct_pk}, accum -> Map.put_new(accum, ct_pk, txi) end,
      & &1
    )
  end

  # def mig1({create_txi, call_txi, log_idx, evt_hash} = log_key) do
  #   [m_log] = :mnesia.read(Model.ContractLog, log_key)
  #   data = Model.contract_log(m_log, :data)
  #   m_data_log = Model.data_contract_log(
  #     index: {data, create_txi, evt_hash, call_txi, log_idx}
  #   )
  #   :mnesia.write(Model.DataContractLog, m_data_log, :write)
  # end

  # def trans1(rev_ct_keys) do
  #   tran = fn {evt_hash, create_txi, call_txi, log_idx} ->
  #     Model.evt_contract_log(index: {evt_hash, call_txi, create_txi, log_idx})
  #   end
  #   Enum.map(rev_ct_keys, tran)
  # end

  # - {{contract_pk, txi, -1}, owner_pk, -1}
  # - {{contract_pk, txi, log_idx}, {from_pk, to_pk}, amount}
  def aex9_presence_cache_write({{contract_pk, txi, i}, pks, amount}),
    do: aex9_presence_cache_write(:aex9_sync_cache, {{contract_pk, txi, i}, pks, amount})

  def aex9_presence_cache_write(ets_tab, {{contract_pk, txi, i}, pks, amount}),
    do: :ets.insert(ets_tab, {{contract_pk, txi, i}, pks, amount})

  def int_call_write(create_txi, call_txi, local_idx, fname, tx) do
    m_call =
      Model.int_contract_call(
        index: {call_txi, local_idx},
        create_txi: create_txi,
        fname: fname,
        tx: tx
      )

    m_grp_call = Model.grp_int_contract_call(index: {create_txi, call_txi, local_idx})
    m_fname_call = Model.fname_int_contract_call(index: {fname, call_txi, local_idx})

    m_fname_grp_call =
      Model.fname_grp_int_contract_call(index: {fname, create_txi, call_txi, local_idx})

    {tx_type, raw_tx} = :aetx.specialize_type(tx)

    :mnesia.write(Model.IntContractCall, m_call, :write)
    :mnesia.write(Model.GrpIntContractCall, m_grp_call, :write)
    :mnesia.write(Model.FnameIntContractCall, m_fname_call, :write)
    :mnesia.write(Model.FnameGrpIntContractCall, m_fname_grp_call, :write)

    for {_, pos} <- AE.tx_ids(tx_type) do
      pk = Validate.id!(elem(raw_tx, pos))
      m_id_call = Model.id_int_contract_call(index: {pk, pos, call_txi, local_idx})

      m_grp_id_call =
        Model.grp_id_int_contract_call(index: {create_txi, pk, pos, call_txi, local_idx})

      m_id_fname_call =
        Model.id_fname_int_contract_call(index: {pk, fname, pos, call_txi, local_idx})

      m_grp_id_fname_call =
        Model.grp_id_fname_int_contract_call(
          index: {create_txi, pk, fname, pos, call_txi, local_idx}
        )

      :mnesia.write(Model.IdIntContractCall, m_id_call, :write)
      :mnesia.write(Model.GrpIdIntContractCall, m_grp_id_call, :write)
      :mnesia.write(Model.IdFnameIntContractCall, m_id_fname_call, :write)
      :mnesia.write(Model.GrpIdFnameIntContractCall, m_grp_id_fname_call, :write)
    end
  end
end

defmodule AeMdw.Db.Contract do
  alias AeMdw.Db.Model
  alias AeMdw.Log

  require Record
  require Model
  require Log

  import AeMdw.Util, only: [compose: 2]
  import AeMdw.Db.Util

  ##########

  def aex9_creation_write({name, symbol, decimals}, contract_pk, txi) do
    aex9_contract = Model.aex9_contract(index: {name, symbol, txi, decimals})
    aex9_contract_sym = Model.aex9_contract_symbol(index: {symbol, name, txi, decimals})
    rev_aex9_contract = Model.rev_aex9_contract(index: {txi, name, symbol, decimals})
    aex9_contract_pk = Model.aex9_contract_pubkey(index: contract_pk, txi: txi)
    :mnesia.write(Model.Aex9Contract, aex9_contract, :write)
    :mnesia.write(Model.Aex9ContractSymbol, aex9_contract_sym, :write)
    :mnesia.write(Model.RevAex9Contract, rev_aex9_contract, :write)
    :mnesia.write(Model.Aex9ContractPubkey, aex9_contract_pk, :write)
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
      result: Model.contract_call(m_call, :result)
    }
  end

  def prefix_tester(""),
    do: fn _ -> true end

  def prefix_tester(prefix) do
    len = String.length(prefix)
    &(String.length(&1) >= len && :binary.part(&1, 0, len) == prefix)
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

  # def block_hash_to_bi(block_hash) do
  #   case :aec_chain.get_block(block_hash) do
  #     {:ok, {_type, header}} ->
  #       height = :aec_headers.height(header)
  #       case height >= last_gen() do
  #         true ->
  #           nil
  #         false ->
  #           case :aec_headers.type(header) do
  #             :key -> {height, -1}
  #             :micro ->
  #               collect_keys(Model.Block, nil, {height, <<>>}, &prev/2, fn
  #                 {^height, _} = bi, nil ->
  #                   Model.block(read_block!(bi), :hash) == block_hash
  #                   && {:halt, bi} || {:cont, nil}
  #                 _k, nil ->
  #                   {:halt, nil}
  #               end)
  #           end
  #       end
  #     :error ->
  #       nil
  #   end
  # end

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
end

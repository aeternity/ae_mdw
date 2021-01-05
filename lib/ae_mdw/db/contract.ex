defmodule AeMdw.Db.Contract do
  alias AeMdw.Db.Model
  alias AeMdw.Log

  require Record
  require Model
  require Log

  import AeMdw.{Util, Db.Util}

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

  # def call_write(create_txi, txi, fname, args, %{error: [err]}),
  #   do: call_write(create_txi, txi, fname, args, :error, err)
  # def call_write(create_txi, txi, fname, args, %{abort: [err]}),
  #   do: call_write(create_txi, txi, fname, args, :abort, err)
  # def call_write(create_txi, txi, fname, args, val),
  #   do: call_write(create_txi, txi, fname, args, :ok, val)

  # def call_write(create_txi, txi, fname, args, result, return) do
  #   m_call = Model.contract_call(
  #     index: {create_txi, txi, fname},
  #     args: args,
  #     result: result,
  #     return: return
  #   )
  #   :mnesia.write(Model.ContractCall, m_call, :write)
  # end

  # def logs_write(create_txi, txi, call_rec) do
  #   contract_pk = :aect_call.contract_pubkey(call_rec)
  #   raw_logs = :aect_call.log(call_rec)

  #   # for {addr, topics, data} in raw_logs do

  #   # end
  # end


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

end

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

  def aex9_read_name(prefix, mode),
    do: aex9_read(Model.Aex9Contract, prefix, mode)

  def aex9_read_symbol(prefix, mode),
    do: aex9_read(Model.Aex9ContractSymbol, prefix, mode)

  def aex9_read(table, prefix, :all),
    do: aex9_read(table, prefix, fn -> [] end, fn _, v, l -> [v | l] end, &Enum.reverse/1)

  def aex9_read(table, prefix, :last),
    do: aex9_read(table, prefix, &:gb_trees.empty/0, &:gb_trees.enter/3, &:gb_trees.values/1)

  def aex9_read(table, exact, :exact) do
    case next(table, {exact, "", 0, 0}) do
      {^exact, _, _, _} = key ->
        key

      _ ->
        nil
    end
  end

  def aex9_read(table, prefix, new, add, return) do
    prefix_len = String.length(prefix)

    prefix? =
      (prefix_len == 0 &&
         fn _ -> true end) ||
        (&(String.length(&1) >= prefix_len && :binary.part(&1, 0, prefix_len) == prefix))

    return.(
      case next(table, {prefix, "", 0, 0}) do
        :"$end_of_table" ->
          new.()

        {s, _, _, _} = start_key ->
          case prefix?.(s) do
            false ->
              new.()

            true ->
              collect_keys(table, add.(s, start_key, new.()), start_key, &next/2, fn {s, _, _, _} =
                                                                                       key,
                                                                                     acc ->
                case prefix?.(s) do
                  false -> {:halt, acc}
                  true -> {:cont, add.(s, key, acc)}
                end
              end)
          end
      end
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

defmodule AeMdw.Contract do
  alias AeMdw.EtsCache

  import :erlang, only: [tuple_to_list: 1]

  import AeMdw.Util

  @tab AeMdw.Contract

  ################################################################################

  def table(), do: @tab

  def get_info(pubkey) do
    case EtsCache.get(@tab, pubkey) do
      {info, _tm} ->
        info

      nil ->
        code =
          ok!(:aec_chain.get_contract(pubkey))
          |> :aect_contracts.code()
          |> :aeser_contract_code.deserialize()

        info =
          case code do
            %{type_info: [], byte_code: byte_code} ->
              :aeb_fate_code.deserialize(byte_code)

            %{type_info: type_info} ->
              type_info
          end

        EtsCache.put(@tab, pubkey, info)
        info
    end
  end

  def decode_call_data(contract, call_data),
    do: decode_call_data(contract, call_data, &id/1)

  def decode_call_data(<<_::256>> = pubkey, call_data, mapper),
    do: decode_call_data(get_info(pubkey), call_data, mapper)

  def decode_call_data({:fcode, _, _, _} = fate_info, call_data, mapper) do
    {:tuple, {fun_hash, {:tuple, tup_args}}} = :aeb_fate_encoding.deserialize(call_data)
    {:ok, fun_name} = :aeb_fate_abi.get_function_name_from_function_hash(fun_hash, fate_info)
    {fun_name, Enum.map(tuple_to_list(tup_args), &fate_val(&1, mapper))}
  end

  def decode_call_data([_ | _] = aevm_info, call_data, mapper) do
    {:ok, fun_hash} = :aeb_aevm_abi.get_function_hash_from_calldata(call_data)
    {:ok, fun_name} = :aeb_aevm_abi.function_name_from_type_hash(fun_hash, aevm_info)
    {:ok, arg_type, _} = :aeb_aevm_abi.typereps_from_type_hash(fun_hash, aevm_info)
    {:ok, {_, vm_args}} = :aeb_heap.from_binary({:tuple, [:word, arg_type]}, call_data)
    {fun_name, aevm_val({arg_type, vm_args}, mapper)}
  end

  def decode_call_result(contract, fun_name, result, value),
    do: decode_call_result(contract, fun_name, result, value, &id/1)

  def decode_call_result(<<_::256>> = pubkey, fun_name, result, value, mapper),
    do: decode_call_result(get_info(pubkey), fun_name, result, value, mapper)

  def decode_call_result(_info, _fun_name, :error, value, mapper),
    do: mapper.(%{error: [value]})

  def decode_call_result({:fcode, _, _, _}, _fun_name, :revert, value, mapper),
    do: mapper.(%{abort: [:aeb_fate_encoding.deserialize(value)]})

  def decode_call_result([_ | _], _fun_name, :revert, value, mapper),
    do: mapper.(%{abort: [ok!(:aeb_heap.from_binary(:string, value))]})

  def decode_call_result({:fcode, _, _, _}, _fun_name, :ok, value, mapper),
    do: fate_val(:aeb_fate_encoding.deserialize(value), mapper)

  def decode_call_result([_ | _] = info, fun_name, :ok, value, mapper) do
    {:ok, hash} = :aeb_aevm_abi.type_hash_from_function_name(fun_name, info)
    {:ok, _, res_type} = :aeb_aevm_abi.typereps_from_type_hash(hash, info)
    {:ok, vm_res} = :aeb_heap.from_binary(res_type, value)
    aevm_val({res_type, vm_res}, mapper)
  end

  def to_map({type, value}), do: %{type: type, value: value}
  def to_map(%{} = map), do: map

  def to_json({type, value}), do: %{"type" => to_string(type), "value" => value}
  def to_json(%{abort: [reason]}), do: %{"abort" => [reason]}
  def to_json(%{error: [reason]}), do: %{"error" => [reason]}

  ##########

  def fate_val(x), do: fate_val(x, &id/1)

  def fate_val({:address, x}, f), do: f.({:address, encode(:account_pubkey, x)})
  def fate_val({:oracle, x}, f), do: f.({:oracle, encode(:oracle_pubkey, x)})
  def fate_val({:oracle_query, x}, f), do: f.({:oracle_query, encode(:oracle_query_id, x)})
  def fate_val({:contract, x}, f), do: f.({:contract, encode(:contract_pubkey, x)})
  def fate_val({:bytes, x}, f), do: f.({:bytes, encode(:bytearray, x)})
  def fate_val({:bits, x}, f), do: f.({:bits, encode(:bytearray, x)})
  def fate_val({:tuple, {}}, f), do: f.({:unit, <<>>})
  def fate_val({:tuple, x}, f), do: f.({:tuple, Enum.map(tuple_to_list(x), &fate_val(&1, f))})
  def fate_val(x, f) when is_integer(x), do: f.({:int, x})
  def fate_val(x, f) when is_boolean(x), do: f.({:bool, x})
  def fate_val(x, f) when is_binary(x), do: f.({:string, x})
  def fate_val(x, f) when is_list(x), do: f.({:list, Enum.map(x, &fate_val(&1, f))})

  def fate_val(x, f) when is_map(x),
    do: f.({:map, Enum.map(x, fn {k, v} -> %{key: fate_val(k, f), val: fate_val(v, f)} end)})

  def fate_val({:variant, _, tag, args}, f),
    do: f.({:variant, [tag | Enum.map(tuple_to_list(args), &fate_val(&1, f))]})

  def aemv_arg(x), do: aevm_val(x, &id/1)

  def aevm_val({:word, x}, f) when is_integer(x), do: f.({:word, x})
  def aevm_val({:string, x}, f) when is_binary(x), do: f.({:string, x})
  def aevm_val({{:option, _t}, :none}, f), do: f.({:option, :none})
  def aevm_val({{:option, t}, {:some, x}}, f), do: f.({:option, aevm_val({t, x}, f)})

  def aevm_val({{:tuple, t}, x}, f),
    do: f.({:tuple, Enum.zip(t, tuple_to_list(x)) |> Enum.map(&aevm_val(&1, f))})

  def aevm_val({{:list, t}, x}, f),
    do: f.({:list, Enum.map(x, &aevm_val({t, &1}, f))})

  def aevm_val({{:variant, cons}, {:variant, tag, args}}, f)
      when is_integer(tag) and tag < length(cons) do
    ts = Enum.at(cons, tag)
    true = length(ts) == length(args)
    f.({:variant, [tag | Enum.map(Enum.zip(ts, args), &aevm_val(&1, f))]})
  end

  def aevm_val({{:map, key_t, val_t}, x}, f) when is_map(x),
    do:
      f.(
        {:map,
         Enum.map(x, fn {k, v} ->
           %{key: aevm_val({key_t, k}, f), val: aevm_val({val_t, v}, f)}
         end)}
      )

  defp encode(type, val),
    do: :aeser_api_encoder.encode(type, val)

  ##########

  def call_tx_info(tx_rec, contract_pk, block_hash, format_fn) do
    ct_info = get_info(contract_pk)
    call_id = :aect_call_tx.call_id(tx_rec)
    call_data = :aect_call_tx.call_data(tx_rec)
    call = :aec_chain.get_contract_call(contract_pk, call_id, block_hash) |> ok!

    {fun, args} = decode_call_data(ct_info, call_data, format_fn)
    fun = to_string(fun)

    res_type = :aect_call.return_type(call)
    res_val = :aect_call.return_value(call)
    result = decode_call_result(ct_info, fun, res_type, res_val, format_fn)

    fun_arg_res = %{
      function: fun,
      arguments: args,
      result: result
    }

    {fun_arg_res, call}
  end
end

defmodule AeMdw.Contract do
  alias AeMdw.EtsCache
  alias AeMdw.Node.Db, as: DBN
  alias AeMdw.Log

  import :erlang, only: [tuple_to_list: 1]

  import AeMdw.Util

  @tab AeMdw.Contract

  ################################################################################

  def table(), do: @tab

  def get_info(pubkey) do
    case EtsCache.get(@tab, pubkey) do
      {info, _tm} ->
        {:ok, info}

      nil ->
        case :aec_chain.get_contract(pubkey) do
          {:ok, contract} ->
            {:code, ser_code} = :aect_contracts.code(contract)

            info =
              case :aeser_contract_code.deserialize(ser_code) do
                %{type_info: [], byte_code: byte_code} ->
                  :aeb_fate_code.deserialize(byte_code)

                %{type_info: type_info} ->
                  type_info
              end

            EtsCache.put(@tab, pubkey, info)
            {:ok, info}

          {:error, reason} ->
            # contract's init can fail, contract_create_tx stays on chain
            # but contract isn't stored in contract store
            {:error, reason}
        end
    end
  end

  ##########

  # entrypoint aex9_extensions : ()             => list(string)
  # entrypoint meta_info       : ()             => meta_info
  # entrypoint total_supply    : ()             => int
  # entrypoint owner           : ()             => address
  # entrypoint balances        : ()             => map(address, int)
  # entrypoint balance         : (address)      => option(int)
  # entrypoint transfer        : (address, int) => unit

  def aex9_signatures() do
    %{
      "aex9_extensions" => {[], {:list, :string}},
      "meta_info" => {[], {:tuple, [:string, :string, :integer]}},
      "total_supply" => {[], :integer},
      "owner" => {[], :address},
      "balances" => {[], {:map, :address, :integer}},
      "balance" => {[:address], {:variant, [tuple: [], tuple: [:integer]]}},
      "transfer" => {[:address, :integer], {:tuple, []}}
    }
  end

  def is_aex9?(pubkey) when is_binary(pubkey) do
    case get_info(pubkey) do
      {:ok, info} -> is_aex9?(info)
      {:error, _} -> false
    end
  end

  def is_aex9?({:fcode, functions, _hash_names, _}) do
    Enum.all?(
      AeMdw.Node.aex9_signatures(),
      fn {hash, type} ->
        case Map.get(functions, hash) do
          {_, ^type, _body} -> true
          _ -> false
        end
      end
    )
  end

  # AEVM
  def is_aex9?(_),
    do: false

  # value of :aec_hash.blake2b_256_hash("Transfer")
  def aex9_transfer_event_hash(),
    do:
      <<34, 60, 57, 226, 157, 255, 100, 103, 254, 221, 160, 151, 88, 217, 23, 129, 197, 55, 46, 9,
        31, 248, 107, 58, 249, 227, 16, 227, 134, 86, 43, 239>>

  def aex9_meta_info(contract_pk),
    do: aex9_meta_info(contract_pk, DBN.top_height_hash(false))

  def aex9_meta_info(contract_pk, {type, height, hash}) do
    {:ok, {:tuple, {name, symbol, decimals}}} =
      call_contract(contract_pk, {type, height, hash}, "meta_info", [])

    {name, symbol, decimals}
  end

  def call_contract(contract_pubkey, function_name, args),
    do: call_contract(contract_pubkey, DBN.top_height_hash(false), function_name, args)

  def call_contract(contract_pubkey, {_, height, block_hash}, function_name, args) do
    {tx_env, trees} = :aetx_env.tx_env_and_trees_from_hash(:aetx_contract, block_hash)
    contracts = :aec_trees.contracts(trees)
    contract = :aect_state_tree.get_contract(contract_pubkey, contracts)

    version = :aect_contracts.ct_version(contract)
    creator = :aect_contracts.owner_pubkey(contract)
    store = :aect_contracts.state(contract)

    caller_pubkey = <<0::256>>
    origin = <<0::256>>
    gas_limit = 1_000_000
    gas_price = 0
    fee = 0
    amount = 0
    call_stack = []

    caller_id = :aeser_id.create(:account, caller_pubkey)
    contract_id = :aect_contracts.id(contract)

    call = :aect_call.new(caller_id, 0, contract_id, height, gas_price)
    {:code, code} = :aect_contracts.code(contract)
    call_data = :aeb_fate_abi.create_calldata('#{function_name}', args) |> ok!

    call_def = %{
      caller: caller_pubkey,
      contract: contract_pubkey,
      fee: fee,
      gas: gas_limit,
      gas_price: gas_price,
      call_data: call_data,
      amount: amount,
      call_stack: call_stack,
      code: code,
      store: store,
      call: call,
      trees: trees,
      tx_env: tx_env,
      off_chain: false,
      origin: origin,
      creator: creator
    }

    {call_res, _trees, _env} = :aect_dispatch.run(version, call_def)

    case :aect_call.return_type(call_res) do
      :ok ->
        res_binary = :aect_call.return_value(call_res)
        {:ok, :aeb_fate_encoding.deserialize(res_binary)}

      :error ->
        {:error, :aect_call.return_value(call_res)}

      :revert ->
        :revert
    end
  end

  def function_hash(name),
    do: :binary.part(:aec_hash.blake2b_256_hash(name), 0, 4)

  ##########

  def decode_call_data(contract, call_data),
    do: decode_call_data(contract, call_data, &id/1)

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
  def fate_val({:bits, x}, f), do: f.({:bits, x})
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

  def aevm_val({k, v}, f) when is_atom(k), do: f.({k, v})

  # this can't be imported, because Elixir complains with:
  # module :aeser_api_encoder is not loaded and could not be found
  defp encode(type, val),
    do: :aeser_api_encoder.encode(type, val)

  ##########

  def call_rec(tx_rec, contract_pk, block_hash) do
    call_id = :aect_call_tx.call_id(tx_rec)
    :aec_chain.get_contract_call(contract_pk, call_id, block_hash) |> ok!
  end

  def call_tx_info(tx_rec, contract_pk, block_hash, format_fn) do
    {:ok, ct_info} = get_info(contract_pk)
    call_id = :aect_call_tx.call_id(tx_rec)
    call_data = :aect_call_tx.call_data(tx_rec)
    call = :aec_chain.get_contract_call(contract_pk, call_id, block_hash) |> ok!

    try do
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
    catch
      _, {:badmatch, match_err} ->
        {{:error, match_err}, call}
    end
  end

  ##########

  def get_events(<<micro_block_hash::binary>>) do
    micro_block = :aec_db.get_block(micro_block_hash)
    :micro = :aec_blocks.type(micro_block)
    get_events(micro_block)
  end

  def get_events(micro_block) when elem(micro_block, 0) == :mic_block do
    header = :aec_blocks.to_header(micro_block)
    {:ok, hash} = :aec_headers.hash_header(header)
    consensus = :aec_headers.consensus_module(header)
    node = {:node, header, hash, :micro}
    time = :aec_block_insertion.node_time(node)
    prev_hash = :aec_block_insertion.node_prev_hash(node)
    prev_key_hash = :aec_block_insertion.node_prev_key_hash(node)
    {:value, prev_key_header} = :aec_db.find_header(prev_key_hash)
    {:value, trees_in, _, _, _, _} = :aec_db.find_block_state_and_data(prev_hash, true)
    trees_in = apply(consensus, :state_pre_transform_micro_node, [node, trees_in])
    env = :aetx_env.tx_env_from_key_header(prev_key_header, prev_key_hash, time, prev_hash)
    txs = :aec_blocks.txs(micro_block)
    {:ok, _, _, events} = :aec_block_micro_candidate.apply_block_txs_strict(txs, trees_in, env)
    ignore_chain_create_or_clone_events(events)
  end

  def ignore_chain_create_or_clone_events(events) do
    Enum.reject(events, &chain_create_or_clone_event?/1)
  end

  defp chain_create_or_clone_event?({{_, "Chain.create"}, _} = event) do
    Log.info("Ignore Chain.create event #{inspect(event)}")
    true
  end

  defp chain_create_or_clone_event?({{_, "Chain.clone"}, _} = event) do
    Log.info("Ignore Chain.clone event #{inspect(event)}")
    true
  end

  defp chain_create_or_clone_event?(_), do: false

  def get_grouped_events(micro_block),
    do: Enum.group_by(get_events(micro_block), fn {_, info} -> info.tx_hash end)

  # def t(gen_range) do
  #   range
  #   |> Stream.flat_map(&AeMdw.Node.Db.get_micro_blocks/1)
  #   |> Stream.map(&:aec_blocks.to_micro_header/1)
  #   |> Stream.map(&ok!(:aec_headers.hash_header(&1)))
  #   |> Stream.flat_map(&AeMdw.Contract.get_events/1)
  # end
end

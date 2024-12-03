defmodule AeMdw.Contract do
  @moduledoc """
  AE smart contracts type (signatures) and previous calls information based on direct chain info.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Name
  alias AeMdw.EtsCache
  alias AeMdw.Log
  alias AeMdw.Node
  alias AeMdw.Node.Db, as: DBN
  alias AeMdw.Util

  import :erlang, only: [tuple_to_list: 1]

  import AeMdw.Util.Encoding, only: [encode_contract: 1, encode: 2]

  @tab __MODULE__

  @type id :: binary()
  @type grouped_events() :: %{tx_hash() => [event()]}
  @type fname :: binary()

  @typep tx_hash :: binary()
  # :aec_blocks.micro_block()
  @typep micro_block :: term()
  @typep event_info :: Node.aetx() | :error
  # :aetx.tx_type()
  @typep event_type :: atom()
  @type event_data :: %{tx_hash: tx_hash(), type: event_type(), info: event_info()}

  @type event :: {{:internal_call_tx, fname()}, event_data()}
  @type event_hash :: <<_::256>>

  @type call :: tuple()

  # for balances or balance
  @type serialized_call :: map()
  # fcode or aevm info
  @type fhash() :: binary()
  @type is_payable() :: boolean()
  @type type_info ::
          {:fcode, map(), map(), map()} | [{fhash(), fname(), is_payable(), binary(), binary()}]
  @type compiler_vsn :: String.t()
  @type source_hash :: <<_::256>>
  @type ct_info :: {type_info(), compiler_vsn(), source_hash()}
  @type function_hash :: <<_::32>>
  @type method_name :: binary()
  @type method_args :: list() | nil
  @type call_tx_args :: list(%{type: atom(), value: term()}) | nil
  @type call_tx_res :: :ok | :invalid | :error | :abort
  @type method_signature :: {list(), atom() | tuple()}
  @type fun_arg_res :: %{
          function: method_name(),
          arguments: call_tx_args(),
          result: call_tx_res(),
          return: any()
        }
  @type fun_arg_res_or_error :: fun_arg_res() | {:error, any()}
  @type local_idx :: non_neg_integer()
  @type code() :: binary()
  @type name_pubkey :: pubkey()
  @type contract_pubkey :: pubkey()
  @opaque aecontract() :: tuple()
  @typep pubkey :: DBN.pubkey()
  @typep tx :: Node.tx()
  @typep signed_tx :: Node.signed_tx()
  @typep block_hash :: <<_::256>>

  @contract_create_fnames ~w(Chain.create Chain.clone Call.create Call.clone)

  defmacro contract_create_fnames do
    quote do
      unquote(@contract_create_fnames)
    end
  end

  @spec table() :: atom()
  def table(), do: @tab

  @spec exists?(DBN.pubkey()) :: boolean()
  def exists?(pubkey) do
    case EtsCache.get(@tab, pubkey) do
      {_info, _tm} -> true
      nil -> match?({:ok, _contract}, :aec_chain.get_contract(pubkey))
    end
  end

  @spec get_info(DBN.pubkey()) :: {:ok, ct_info()} | {:error, any()}
  def get_info(pubkey) do
    case EtsCache.get(@tab, pubkey) do
      {info, _tm} ->
        {:ok, info}

      nil ->
        # when contract init fails, contract_create_tx stays on chain
        # but contract isn't stored in contract store
        with {:ok, _contract, ser_code} <- :aec_chain.get_contract_with_code(pubkey) do
          code_map = :aeser_contract_code.deserialize(ser_code)
          # might be stripped
          compiler_version = Map.get(code_map, :compiler_version)
          source_hash = Map.get(code_map, :source_hash)

          type_info =
            case code_map do
              %{type_info: [], byte_code: byte_code} ->
                :aeb_fate_code.deserialize(byte_code)

              %{type_info: type_info} ->
                type_info
            end

          info = {type_info, compiler_version, source_hash}
          EtsCache.put(@tab, pubkey, info)

          {:ok, info}
        end
    end
  end

  @spec aex9_signatures() :: %{method_name() => method_signature()}
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

  @option_string {:variant, [tuple: [], tuple: [:string]]}

  @spec aex141_signatures() :: %{method_name() => method_signature()}
  def aex141_signatures() do
    metadata_type = {:variant, [tuple: [], tuple: [], tuple: []]}

    %{
      "aex141_extensions" => {[], {:list, :string}},
      "meta_info" =>
        {[],
         {:tuple, [:string, :string, {:variant, [tuple: [], tuple: [:string]]}, metadata_type]}},
      "balance" => {[:address], {:variant, [tuple: [], tuple: [:integer]]}},
      "total_supply" => {[], :integer},
      "owner" => {[:integer], {:variant, [tuple: [], tuple: [:address]]}},
      "transfer" => {[:address, :integer, @option_string], {:tuple, []}},
      "approve" => {[:address, :integer, :boolean], {:tuple, []}},
      "approve_all" => {[:address, :boolean], {:tuple, []}},
      "get_approved" => {[:integer], {:variant, [tuple: [], tuple: [:address]]}},
      "is_approved" => {[:integer, :address], :boolean},
      "is_approved_for_all" => {[:address, :address], :boolean}
    }
  end

  @spec previous_aex141_signatures() :: %{method_name() => method_signature()}
  def previous_aex141_signatures() do
    metadata_type = {:variant, [tuple: [], tuple: [], tuple: [], tuple: []]}

    aex141_signatures()
    |> Map.delete("total_supply")
    |> Map.put("transfer", {[:address, :address, :integer, @option_string], {:tuple, []}})
    |> Map.put(
      "meta_info",
      {[], {:tuple, [:string, :string, {:variant, [tuple: [], tuple: [:string]]}, metadata_type]}}
    )
  end

  @spec function_hash(String.t()) :: function_hash()
  def function_hash(name),
    do: :binary.part(:aec_hash.blake2b_256_hash(name), 0, 4)

  defp decode_call_data(contract, call_data),
    do: decode_call_data(contract, call_data, &Util.id/1)

  defp decode_call_data({:fcode, _funs, _syms, _annotations} = fate_info, call_data, mapper) do
    {:tuple, {fun_hash, {:tuple, tup_args}}} = :aeb_fate_encoding.deserialize(call_data)

    # sample fun_hash not matching: <<74, 202, 20, 78, 108, 15, 83, 141, 70, 92, 69, 235, 191, 127, 43, 123, 21, 80, 189, 1, 86, 76, 125, 166, 246, 81, 67, 150, 69, 95, 156, 6>>
    case :aeb_fate_abi.get_function_name_from_function_hash(fun_hash, fate_info) do
      {:ok, fun_name} ->
        {fun_name, Enum.map(tuple_to_list(tup_args), &fate_val(&1, mapper))}

      {:error, :no_function_matching_function_hash} ->
        {:error, :no_function_matching_function_hash}
    end
  end

  defp decode_call_data([_ | _] = aevm_info, call_data, mapper) do
    {:ok, fun_hash} = :aeb_aevm_abi.get_function_hash_from_calldata(call_data)
    {:ok, fun_name} = :aeb_aevm_abi.function_name_from_type_hash(fun_hash, aevm_info)
    {:ok, arg_type, _type_rep} = :aeb_aevm_abi.typereps_from_type_hash(fun_hash, aevm_info)
    {:ok, {_arg_type, vm_args}} = :aeb_heap.from_binary({:tuple, [:word, arg_type]}, call_data)
    {fun_name, aevm_val({arg_type, vm_args}, mapper)}
  end

  defp decode_call_result({:fcode, _functions, _symbols, _annotations}, _fun_name, value, mapper),
    do: fate_val(:aeb_fate_encoding.deserialize(value), mapper)

  defp decode_call_result([_arg_type | _ret_type] = info, fun_name, value, mapper) do
    {:ok, hash} = :aeb_aevm_abi.type_hash_from_function_name(fun_name, info)
    {:ok, _type_rep, res_type} = :aeb_aevm_abi.typereps_from_type_hash(hash, info)

    case :aeb_heap.from_binary(res_type, value) do
      {:ok, vm_res} -> aevm_val({res_type, vm_res}, mapper)
      {:error, reason} -> "error decoding: #{inspect(reason)}"
    end
  end

  @spec call_rec(signed_tx(), DBN.pubkey(), block_hash()) :: {:ok, call()} | {:error, atom()}
  def call_rec(signed_tx, contract_pk, block_hash) do
    {mod, tx_rec} = signed_tx |> :aetx_sign.tx() |> :aetx.specialize_callback()

    tx_rec
    |> mod.call_id()
    |> call_rec_from_id(contract_pk, block_hash)
  end

  @spec call_tx_info(tx(), DBN.pubkey(), DBN.pubkey(), block_hash()) ::
          {fun_arg_res_or_error(), call()}
  def call_tx_info(tx_rec, contract_pk, contract_or_name_pk, block_hash) do
    {:ok, {type_info, _compiler_vsn, _source_hash}} = get_info(contract_pk)
    call_id = :aect_call_tx.call_id(tx_rec)
    call_data = :aect_call_tx.call_data(tx_rec)

    case :aec_chain.get_contract_call(contract_or_name_pk, call_id, block_hash) do
      {:ok, call} ->
        case :aect_call.return_type(call) do
          :error ->
            {:error, call}

          :ok ->
            {fun, args} = decode_call_data(type_info, call_data, &to_map/1)
            fun = to_string(fun)
            res_val = :aect_call.return_value(call)
            result = decode_call_result(type_info, fun, res_val, &to_map/1)

            fun_arg_res = %{
              function: fun,
              arguments: args,
              result: result
            }

            {fun_arg_res, call}

          :revert ->
            {fun, args} = decode_call_data(type_info, call_data, &to_map/1)
            fun = to_string(fun)

            fun_arg_res = %{
              function: fun,
              arguments: args,
              result: :invalid
            }

            {fun_arg_res, call}
        end

      {:error, reason} ->
        Log.error(
          "call_tx_info error reason=#{inspect(reason)} params=#{inspect([contract_or_name_pk, call_id, block_hash])}"
        )

        {{:error, reason}, nil}
    end
  end

  @spec get_init_call_rec(tx(), block_hash()) :: call() | nil
  def get_init_call_rec(tx_rec, block_hash) do
    contract_pk = :aect_create_tx.contract_pubkey(tx_rec)
    create_nonce = :aect_create_tx.nonce(tx_rec)

    call_id =
      tx_rec
      |> :aect_create_tx.owner_pubkey()
      |> :aect_call.id(create_nonce, contract_pk)

    case call_rec_from_id(call_id, contract_pk, block_hash) do
      {:ok, call_rec} ->
        call_rec

      {:error, reason} ->
        Log.error(
          "get_init_call_rec error reason=#{inspect(reason)} params=#{inspect([contract_pk, call_id, block_hash])}"
        )

        nil
    end
  end

  @spec get_init_call_details(tx(), block_hash()) :: serialized_call()
  def get_init_call_details(tx_rec, block_hash) do
    contract_pk = :aect_create_tx.contract_pubkey(tx_rec)
    {compiler_vsn, source_hash} = compilation_info(contract_pk)

    call_details = %{
      "contract_id" => encode_contract(contract_pk),
      "args" => contract_init_args(contract_pk, tx_rec),
      "compiler_version" => compiler_vsn,
      "source_hash" => source_hash && Base.encode64(source_hash)
    }

    call_rec = get_init_call_rec(tx_rec, block_hash)

    if call_rec do
      call_ser =
        call_rec
        |> :aect_call.serialize_for_client()
        |> Map.drop(["gas_price", "height", "caller_nonce"])
        |> Map.update("log", [], &stringfy_log_topics/1)

      Map.merge(call_ser, call_details)
    else
      call_details
    end
  end

  @spec get_ga_attach_call_details(signed_tx(), pubkey(), block_hash()) :: serialized_call()
  def get_ga_attach_call_details(signed_tx, contract_pk, block_hash) do
    {:aega_attach_tx, tx_rec} = signed_tx |> :aetx_sign.tx() |> :aetx.specialize_callback()

    call_details = %{
      "auth_fun_name" => get_ga_attach_auth_func_name(tx_rec, contract_pk),
      "args" => contract_init_args(contract_pk, tx_rec, :aega_attach_tx)
    }

    case call_rec(signed_tx, contract_pk, block_hash) do
      {:ok, call_rec} ->
        Map.merge(call_details, %{
          "gas_used" => :aect_call.gas_used(call_rec),
          "return_type" => :aect_call.return_type(call_rec)
        })

      {:error, _reason} ->
        Map.merge(call_details, %{
          "gas_used" => nil,
          "return_type" => nil
        })
    end
  end

  defp get_ga_attach_auth_func_name(tx_rec, contract_pk) do
    with <<auth_fun_hash_key::binary-4, _rest::binary>> <- :aega_attach_tx.auth_fun(tx_rec),
         {:ok, {{:fcode, _code, names, _extra}, _version, _hash}} <- get_info(contract_pk) do
      Map.get(names, auth_fun_hash_key)
    else
      _mismatch_or_error -> nil
    end
  end

  @spec stringfy_log_topics([map()]) :: [map()]
  def stringfy_log_topics(logs) do
    Enum.map(logs, fn log ->
      Map.update(log, "topics", [], fn xs ->
        Enum.map(xs, &to_string/1)
      end)
    end)
  end

  @spec get_grouped_events(micro_block()) :: grouped_events()
  def get_grouped_events(micro_block) do
    Enum.group_by(get_events(micro_block), fn {_event_name, %{tx_hash: tx_hash}} -> tx_hash end)
  end

  @spec maybe_resolve_contract_pk(name_pubkey() | contract_pubkey(), Blocks.block_hash()) ::
          contract_pubkey()
  def maybe_resolve_contract_pk(contract_or_name_pk, block_hash) do
    contract_or_name_pk
    |> case do
      <<217, 52, 92, _rest::binary>> = name_pk ->
        block_hash
        |> Name.ptr_resolve(name_pk, "contract_pubkey")
        |> case do
          {:ok, contract_pk} ->
            contract_pk

          {:error, reason} ->
            raise "Contract not resolved: #{inspect(contract_or_name_pk)} with reason #{inspect(reason)}"
        end

      contract_pk ->
        contract_pk
    end
  end

  #
  # Private functions
  #
  defp to_map({type, value}), do: %{type: type, value: value}
  defp to_map(%{} = map), do: map

  # encoding and decoding vm data
  defp fate_val({:address, x}, f), do: f.({:address, encode(:account_pubkey, x)})
  defp fate_val({:oracle, x}, f), do: f.({:oracle, encode(:oracle_pubkey, x)})
  defp fate_val({:oracle_query, x}, f), do: f.({:oracle_query, encode(:oracle_query_id, x)})
  defp fate_val({:contract, x}, f), do: f.({:contract, encode(:contract_pubkey, x)})
  defp fate_val({:bytes, x}, f), do: f.({:bytes, encode(:bytearray, x)})
  defp fate_val({:bits, x}, f), do: f.({:bits, x})
  defp fate_val({:tuple, {}}, f), do: f.({:unit, <<>>})
  defp fate_val({:tuple, x}, f), do: f.({:tuple, Enum.map(tuple_to_list(x), &fate_val(&1, f))})
  defp fate_val(x, f) when is_integer(x), do: f.({:int, x})
  defp fate_val(x, f) when is_boolean(x), do: f.({:bool, x})
  defp fate_val(x, f) when is_binary(x), do: f.({:string, x})
  defp fate_val(x, f) when is_list(x), do: f.({:list, Enum.map(x, &fate_val(&1, f))})

  defp fate_val(x, f) when is_map(x),
    do: f.({:map, Enum.map(x, fn {k, v} -> %{key: fate_val(k, f), val: fate_val(v, f)} end)})

  defp fate_val({:variant, _bytecode, tag, args}, f),
    do: f.({:variant, [tag | Enum.map(tuple_to_list(args), &fate_val(&1, f))]})

  defp aevm_val({:word, x}, f) when is_integer(x), do: f.({:word, x})
  defp aevm_val({:string, x}, f) when is_binary(x), do: f.({:string, x})
  defp aevm_val({{:option, _t}, :none}, f), do: f.({:option, :none})
  defp aevm_val({{:option, t}, {:some, x}}, f), do: f.({:option, aevm_val({t, x}, f)})

  defp aevm_val({{:tuple, type}, vm_args_res}, f) do
    aevm_value =
      type
      |> Enum.zip(tuple_to_list(vm_args_res))
      |> Enum.map(&aevm_val(&1, f))

    f.({:tuple, aevm_value})
  end

  defp aevm_val({{:list, t}, x}, f),
    do: f.({:list, Enum.map(x, &aevm_val({t, &1}, f))})

  defp aevm_val({{:variant, cons}, {:variant, tag, args}}, f)
       when is_integer(tag) and tag < length(cons) do
    ts = Enum.at(cons, tag)
    true = length(ts) == length(args)
    f.({:variant, [tag | Enum.map(Enum.zip(ts, args), &aevm_val(&1, f))]})
  end

  defp aevm_val({{:map, key_t, val_t}, x}, f) when is_map(x),
    do:
      f.(
        {:map,
         Enum.map(x, fn {k, v} ->
           %{key: aevm_val({key_t, k}, f), val: aevm_val({val_t, v}, f)}
         end)}
      )

  defp aevm_val({k, v}, f) when is_atom(k), do: f.({k, v})
  ###

  defp get_events(micro_block) when elem(micro_block, 0) == :mic_block do
    txs = :aec_blocks.txs(micro_block)
    height = :aec_blocks.height(micro_block)
    txs_taken = txs_until_last_contract_tx(txs)

    if txs_taken != [] do
      header = :aec_blocks.to_header(micro_block)
      consensus = :aec_headers.consensus_module(header)
      node = :aec_chain_state.wrap_block(micro_block)
      time = :aec_block_insertion.node_time(node)
      prev_hash = :aec_block_insertion.node_prev_hash(node)
      prev_key_hash = :aec_block_insertion.node_prev_key_hash(node)
      {:value, prev_key_header} = :aec_db.find_header(prev_key_hash)

      {:value, trees_in, _difficulty, _fork_id, _fees, _fraud} =
        :aec_db.find_block_state_and_data(prev_hash, true)

      trees_in = consensus.state_pre_transform_micro_node(height, node, trees_in)
      env = :aetx_env.tx_env_from_key_header(prev_key_header, prev_key_hash, time, prev_hash)

      {:ok, _sigs, _trees, events} =
        :aec_block_micro_candidate.apply_block_txs_strict(txs_taken, trees_in, env)

      events
    else
      []
    end
  end

  defp txs_until_last_contract_tx(mb_txs) do
    {tx_pos, last_ct_tx_pos} =
      Enum.reduce(mb_txs, {1, -1}, fn signed_tx, {tx_pos, last_index} ->
        {mod, _tx} = :aetx.specialize_callback(:aetx_sign.tx(signed_tx))

        if mod.type() in [:contract_create_tx, :contract_call_tx] do
          {tx_pos + 1, tx_pos}
        else
          {tx_pos + 1, last_index}
        end
      end)

    case last_ct_tx_pos do
      -1 -> []
      ^tx_pos -> mb_txs
      ^last_ct_tx_pos -> Enum.take(mb_txs, last_ct_tx_pos)
    end
  end

  defp call_rec_from_id(call_id, contract_pk, block_hash) do
    :aec_chain.get_contract_call(contract_pk, call_id, block_hash)
  end

  defp compilation_info(contract_pk) do
    case get_info(contract_pk) do
      {:ok, {_type_info, compiler_vsn, source_hash}} -> {compiler_vsn, source_hash}
      {:error, _reason} -> {nil, nil}
    end
  end

  defp contract_init_args(contract_pk, tx_rec, mod \\ :aect_create_tx) do
    with {:ok, {type_info, _compiler_vsn, _source_hash}} <- get_info(contract_pk),
         call_data <- mod.call_data(tx_rec),
         {"init", args} <- decode_call_data(type_info, call_data) do
      args_type_value(args)
    else
      {:error, _reason} -> nil
    end
  end

  defp args_type_value(args) when is_list(args) do
    Enum.map(args, &type_value_map/1)
  end

  defp args_type_value(type_value), do: type_value_map(type_value)

  defp type_value_map({type, list}) when is_list(list) do
    %{
      "type" => to_string(type),
      "value" => Enum.map(list, &element_value/1)
    }
  end

  defp type_value_map({type, value}) do
    %{
      "type" => to_string(type),
      "value" => value
    }
  end

  defp element_value({type, [head | _tail] = keyword_list})
       when is_atom(type) and is_tuple(head) and tuple_size(head) == 2 do
    %{
      "type" => to_string(type),
      "value" => Enum.into(keyword_list, %{})
    }
  end

  defp element_value({_type, value}), do: value

  defp element_value(%{key: {_key_type, key_value}, val: {_val_type, val_value}}),
    do: %{"key" => key_value, "val" => val_value}

  defp element_value(x), do: x
end

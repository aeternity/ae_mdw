defmodule AeMdw.Contract do
  # credo:disable-for-this-file
  @moduledoc """
  AE Smart Contracts info and calls.
  """

  alias AeMdw.EtsCache
  alias AeMdw.Node
  alias AeMdw.Node.Db, as: DBN
  alias AeMdw.DryRun
  alias AeMdw.Log
  alias AeMdw.Validate

  import :erlang, only: [tuple_to_list: 1]

  import AeMdw.Util

  @tab __MODULE__

  @type id :: binary()
  @type grouped_events() :: %{tx_hash() => [event()]}
  @type fname :: binary()

  @typep tx_hash :: binary()
  @typep event_name :: {:internal_call_tx, fname()}
  # :aec_blocks.micro_block()
  @typep micro_block :: term()
  @typep event_info :: Node.aetx() | :error
  # :aetx.tx_type()
  @typep event_type :: atom()
  @typep event_data :: %{tx_hash: tx_hash(), type: event_type(), info: event_info()}

  @type event :: {event_name(), event_data()}
  @type event_hash :: <<_::256>>

  @type call :: tuple()

  @type aex9_meta_info() :: {String.t(), String.t(), integer()}
  # for balances or balance
  @type call_result :: map() | tuple()
  @type serialized_call :: map()
  # fcode or aevm info
  @type type_info :: {:fcode, map(), list(), any()} | list()
  @type compiler_vsn :: String.t()
  @type source_hash :: <<_::256>>
  @type ct_info :: {type_info(), compiler_vsn(), source_hash()}
  @type function_hash :: <<_::32>>
  @type method_name :: binary()
  @type method_args :: list()
  @type fun_arg_res :: %{
          function: method_name(),
          arguments: method_args(),
          result: any(),
          return: any()
        }
  @type fun_arg_res_or_error :: fun_arg_res() | {:error, any()}
  @type local_idx() :: non_neg_integer()
  @typep tx :: Node.tx()
  @typep block_hash :: <<_::256>>

  @aex9_transfer_event_hash <<34, 60, 57, 226, 157, 255, 100, 103, 254, 221, 160, 151, 88, 217,
                              23, 129, 197, 55, 46, 9, 31, 248, 107, 58, 249, 227, 16, 227, 134,
                              86, 43, 239>>

  ################################################################################
  @spec table() :: atom()
  def table(), do: @tab

  @spec is_contract?(DBN.pubkey()) :: boolean()
  def is_contract?(pubkey) do
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
        with {:ok, contract} <- :aec_chain.get_contract(pubkey),
             {:ok, ser_code} <- get_code(contract) do
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
        else
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

  @spec aex9_signatures() :: map()
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

  @spec aex141_signatures() :: map()
  def aex141_signatures() do
    %{
      "aex141_extensions" => {[], {:list, :string}},
      "meta_info" =>
        {[], {:tuple, [:string, :string, {:variant, [tuple: [], tuple: [:string]]}, :atom]}},
      "metadata" =>
        {[:integer], {:variant, [tuple: [:string], tuple: [{:map, :string, :string}]]}},
      "mint" => {[:address, {:variant, [tuple: [], tuple: [:string]]}], :integer},
      "balance" => {[:address], {:variant, [tuple: [], tuple: [:integer]]}},
      "owner" => {[:integer], {:variant, [tuple: [], tuple: [:address]]}},
      "transfer" => {[:address, :address, :integer], {:tuple, []}},
      "approve" => {[:address, :integer, :boolean], {:tuple, []}},
      "approve_all" => {[:address, :boolean], {:tuple, []}},
      "get_approved" => {[:integer], {:variant, [tuple: [], tuple: [:address]]}},
      "is_approved" => {[:integer, :address], :boolean},
      "is_approved_for_all" => {[:address, :address], :boolean}
    }
  end

  @spec extract_successful_function(fun_arg_res_or_error()) ::
          {:ok, method_name(), method_args()} | :not_found
  def extract_successful_function({:error, _reason}), do: :not_found
  def extract_successful_function(%{result: %{error: _error}}), do: :not_found
  def extract_successful_function(%{result: %{abort: _error}}), do: :not_found

  def extract_successful_function(%{function: method_name, arguments: method_args}) do
    {:ok, method_name, method_args}
  end

  @spec is_success_ct_call?(fun_arg_res_or_error()) :: boolean
  def is_success_ct_call?({:error, _reason}), do: false
  def is_success_ct_call?(%{result: %{error: _error}}), do: false
  def is_success_ct_call?(%{result: %{abort: _error}}), do: false
  def is_success_ct_call?(_result_ok), do: true

  @spec is_non_stateful_aex9_function?(method_name()) :: boolean()
  def is_non_stateful_aex9_function?(<<method_name::binary>>) do
    method_name in [
      "aex9_extensions",
      "meta_info",
      "total_supply",
      "owner",
      "balance",
      "balances"
    ]
  end

  @spec get_aex9_transfer(DBN.pubkey(), String.t(), term()) ::
          {DBN.pubkey(), DBN.pubkey(), non_neg_integer()} | nil
  def get_aex9_transfer(from_pk, "transfer", [
        %{type: :address, value: to_account_id},
        %{type: :int, value: value}
      ]),
      do: {from_pk, Validate.id!(to_account_id), value}

  def get_aex9_transfer(_caller_pk, "transfer_allowance", [
        %{type: :address, value: from_account_id},
        %{type: :address, value: to_account_id},
        %{type: :int, value: value}
      ]),
      do: {Validate.id!(from_account_id), Validate.id!(to_account_id), value}

  def get_aex9_transfer(_caller_pk, _other_function, _other_args), do: nil

  @spec is_aex9?(DBN.pubkey() | type_info()) :: boolean()
  def is_aex9?(pubkey) when is_binary(pubkey) do
    case get_info(pubkey) do
      {:ok, {type_info, _compiler_vsn, _source_hash}} -> is_aex9?(type_info)
      {:error, _reason} -> false
    end
  end

  def is_aex9?({:fcode, functions, _hash_names, _code}) do
    AeMdw.Node.aex9_signatures()
    |> has_all_signatures?(functions)
  end

  # AEVM
  def is_aex9?(_no_fcode), do: false

  def is_aex141?({:fcode, functions, _hash_names, _code}) do
    AeMdw.Node.aex141_signatures()
    |> has_all_signatures?(functions)
  end

  # AEVM
  def is_aex141?(_no_fcode), do: false

  # value of :aec_hash.blake2b_256_hash("Transfer")
  @spec aex9_transfer_event_hash() :: event_hash()
  def aex9_transfer_event_hash(), do: @aex9_transfer_event_hash

  @spec aex9_meta_info(DBN.pubkey()) :: {:ok, aex9_meta_info()} | :not_found
  def aex9_meta_info(contract_pk),
    do: aex9_meta_info(contract_pk, DBN.top_height_hash(false))

  def aex9_meta_info(contract_pk, {type, height, hash}) do
    case call_contract(contract_pk, {type, height, hash}, "meta_info", []) do
      {:ok, {:tuple, {name, symbol, decimals}}} ->
        {:ok, {name, symbol, decimals}}

      {:error, _call_error} ->
        Log.info(
          "aex9_meta_info not available for #{
            :aeser_api_encoder.encode(:contract_pubkey, contract_pk)
          }"
        )

        :not_found
    end
  end

  @spec call_contract(DBN.pubkey(), String.t(), list()) ::
          {:ok, call_result()} | {:error, any()} | :revert
  def call_contract(contract_pk, function_name, args),
    do: call_contract(contract_pk, DBN.top_height_hash(false), function_name, args)

  def call_contract(contract_pk, {_type, _height, block_hash}, function_name, args) do
    contract_pk
    |> DryRun.Runner.new_contract_call_tx(block_hash, function_name, args)
    |> DryRun.Runner.dry_run(block_hash)
    |> case do
      {:ok, {[contract_call_tx: {:ok, call_res}], _events}} ->
        case :aect_call.return_type(call_res) do
          :ok ->
            res_binary = :aect_call.return_value(call_res)
            {:ok, :aeb_fate_encoding.deserialize(res_binary)}

          :error ->
            {:error, :aect_call.return_value(call_res)}

          :revert ->
            :revert
        end

      _error ->
        {:error, :dry_run_error}
    end
  end

  @spec function_hash(String.t()) :: function_hash()
  def function_hash(name),
    do: :binary.part(:aec_hash.blake2b_256_hash(name), 0, 4)

  ##########

  defp get_code(contract) do
    case :aect_contracts.code(contract) do
      {:code, ser_code} ->
        {:ok, ser_code}

      {:ref, {:id, :contract, pubkey}} ->
        case :aec_chain.get_contract(pubkey) do
          {:ok, contract} ->
            get_code(contract)

          error ->
            error
        end
    end
  end

  defp decode_call_data(contract, call_data),
    do: decode_call_data(contract, call_data, &id/1)

  defp decode_call_data({:fcode, _, _, _} = fate_info, call_data, mapper) do
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
    {:ok, arg_type, _} = :aeb_aevm_abi.typereps_from_type_hash(fun_hash, aevm_info)
    {:ok, {_, vm_args}} = :aeb_heap.from_binary({:tuple, [:word, arg_type]}, call_data)
    {fun_name, aevm_val({arg_type, vm_args}, mapper)}
  end

  defp decode_call_result(_info, _fun_name, :error, value, mapper),
    do: mapper.(%{error: [value]})

  defp decode_call_result({:fcode, _, _, _}, _fun_name, :revert, value, mapper),
    do: mapper.(%{abort: [:aeb_fate_encoding.deserialize(value)]})

  defp decode_call_result([_ | _], _fun_name, :revert, value, mapper),
    do: mapper.(%{abort: [ok!(:aeb_heap.from_binary(:string, value))]})

  defp decode_call_result({:fcode, _, _, _}, _fun_name, :ok, value, mapper),
    do: fate_val(:aeb_fate_encoding.deserialize(value), mapper)

  defp decode_call_result([_ | _] = info, fun_name, :ok, value, mapper) do
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

  @spec call_rec(tx(), DBN.pubkey(), block_hash()) :: call()
  def call_rec(tx_rec, contract_pk, block_hash) do
    tx_rec
    |> :aect_call_tx.call_id()
    |> call_rec_from_id(contract_pk, block_hash)
  end

  @spec call_tx_info(tx(), DBN.pubkey(), block_hash(), fun()) :: {fun_arg_res_or_error(), call()}
  def call_tx_info(tx_rec, contract_pk, block_hash, format_fn) do
    {:ok, {type_info, _compiler_vsn, _source_hash}} = get_info(contract_pk)
    call_id = :aect_call_tx.call_id(tx_rec)
    call_data = :aect_call_tx.call_data(tx_rec)
    call = :aec_chain.get_contract_call(contract_pk, call_id, block_hash) |> ok!

    try do
      {fun, args} = decode_call_data(type_info, call_data, format_fn)
      fun = to_string(fun)

      res_type = :aect_call.return_type(call)
      res_val = :aect_call.return_value(call)
      result = decode_call_result(type_info, fun, res_type, res_val, format_fn)

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

  @spec get_init_call_rec(tx(), block_hash()) :: call()
  def get_init_call_rec(tx_rec, block_hash) do
    contract_pk = :aect_create_tx.contract_pubkey(tx_rec)
    create_nonce = :aect_create_tx.nonce(tx_rec)

    tx_rec
    |> :aect_create_tx.owner_pubkey()
    |> :aect_call.id(create_nonce, contract_pk)
    |> call_rec_from_id(contract_pk, block_hash)
  end

  @spec get_init_call_details(tx(), block_hash()) :: serialized_call()
  def get_init_call_details(tx_rec, block_hash) do
    contract_pk = :aect_create_tx.contract_pubkey(tx_rec)
    {compiler_vsn, source_hash} = compilation_info(contract_pk)

    tx_rec
    |> get_init_call_rec(block_hash)
    |> :aect_call.serialize_for_client()
    |> Map.drop(["gas_price", "height", "caller_nonce"])
    |> Map.put("args", contract_init_args(contract_pk, tx_rec))
    |> Map.update("log", [], &stringfy_log_topics/1)
    |> Map.put("compiler_version", compiler_vsn)
    |> Map.put("source_hash", source_hash && Base.encode64(source_hash))
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

  #
  # Private functions
  #
  defp has_all_signatures?(aexn_signatures, functions) do
    Enum.all?(aexn_signatures, fn {hash, type} ->
      match?({_code, ^type, _body}, Map.get(functions, hash))
    end)
  end

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

  defp fate_val({:variant, _, tag, args}, f),
    do: f.({:variant, [tag | Enum.map(tuple_to_list(args), &fate_val(&1, f))]})

  defp aevm_val({:word, x}, f) when is_integer(x), do: f.({:word, x})
  defp aevm_val({:string, x}, f) when is_binary(x), do: f.({:string, x})
  defp aevm_val({{:option, _t}, :none}, f), do: f.({:option, :none})
  defp aevm_val({{:option, t}, {:some, x}}, f), do: f.({:option, aevm_val({t, x}, f)})

  defp aevm_val({{:tuple, t}, x}, f),
    do: f.({:tuple, Enum.zip(t, tuple_to_list(x)) |> Enum.map(&aevm_val(&1, f))})

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

  # this can't be imported, because Elixir complains with:
  # module :aeser_api_encoder is not loaded and could not be found
  defp encode(type, val),
    do: :aeser_api_encoder.encode(type, val)

  ###

  defp get_events(micro_block) when elem(micro_block, 0) == :mic_block do
    txs = :aec_blocks.txs(micro_block)
    txs_taken = txs_until_last_contract_tx(txs)

    if txs_taken != [] do
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

      {:ok, _, _, events} =
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
    :aec_chain.get_contract_call(contract_pk, call_id, block_hash) |> ok!
  end

  defp compilation_info(contract_pk) do
    case get_info(contract_pk) do
      {:ok, {_type_info, compiler_vsn, source_hash}} -> {compiler_vsn, source_hash}
      {:error, _reason} -> {nil, nil}
    end
  end

  defp contract_init_args(contract_pk, tx_rec) do
    with {:ok, {type_info, _compiler_vsn, _source_hash}} <- get_info(contract_pk),
         call_data <- :aect_create_tx.call_data(tx_rec),
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

  defp element_value({_type, value}), do: value

  defp element_value(%{key: {_key_type, key_value}, val: {_val_type, val_value}}),
    do: %{"key" => key_value, "val" => val_value}

  defp element_value(x), do: x
end

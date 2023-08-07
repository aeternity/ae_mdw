defmodule AeMdw.AexnContracts do
  @moduledoc """
  AEX-N detection and common calls to interact with the contract.
  """

  alias AeMdw.Contract
  alias AeMdw.Db.Model
  alias AeMdw.DryRun.Runner
  alias AeMdw.Node
  alias AeMdw.Log

  import AeMdw.Util.Encoding, only: [encode_contract: 1]

  @type event_name() :: String.t()
  @typep pubkey :: Node.Db.pubkey()
  @typep height :: AeMdw.Blocks.height()
  @typep block_hash :: Node.Db.hash()
  @typep height_hash :: Node.Db.height_hash()
  @typep type_info :: Contract.type_info()
  @typep aexn_meta_info :: AeMdw.Db.Model.aexn_meta_info()

  @aex9_extensions_hash <<49, 192, 141, 115>>
  @aex141_extensions_hash <<222, 10, 63, 194>>

  @spec is_aex9?(pubkey() | type_info()) :: boolean()
  def is_aex9?(pubkey) when is_binary(pubkey) do
    case Contract.get_info(pubkey) do
      {:ok, {type_info, _compiler_vsn, _source_hash}} -> is_aex9?(type_info)
      {:error, _reason} -> false
    end
  end

  def is_aex9?({:fcode, functions, _hash_names, _code}) do
    AeMdw.Node.aex9_signatures()
    |> has_all_signatures?(functions)
  end

  def is_aex9?(_no_fcode), do: false

  @spec has_aex141_signatures?(height(), type_info()) :: boolean()
  def has_aex141_signatures?(height, {:fcode, functions, _hash_names, _code}) do
    signatures = :aec_governance.get_network_id() |> get_aex141_signatures(height)

    has_all_signatures?(signatures, functions) and valid_aex141_metadata?(functions)
  end

  def has_aex141_signatures?(_height, _no_fcode), do: false

  @spec has_valid_aex141_extensions?(Model.aexn_extensions(), Contract.type_info()) ::
          boolean()
  def has_valid_aex141_extensions?(extensions, {:fcode, functions, _hash_names, _code}) do
    Enum.all?(extensions, &valid_aex141_extension?(&1, functions))
  end

  def has_valid_aex141_extensions?(_extensions, _no_fcode), do: false

  @spec call_meta_info(Model.aexn_type(), pubkey(), block_hash()) :: {:ok, Model.aexn_meta_info()}
  def call_meta_info(aexn_type, contract_pk, mb_hash) do
    case call_contract(contract_pk, "meta_info", [], mb_hash) do
      {:ok, {:tuple, meta_info_tuple}} ->
        {:ok, decode_meta_info(aexn_type, meta_info_tuple)}

      {:error, reason} when reason in [:contract_does_not_exist, :block_not_found] ->
        :error

      {:error, _reason} ->
        {:ok, call_error_meta_info(aexn_type)}
    end
  end

  @spec get_extensions(Model.aexn_type(), pubkey(), type_info()) ::
          {:ok, Model.aexn_extensions()} | :error
  def get_extensions(aexn_type, pubkey, type_info) do
    case aexn_type do
      :aex9 ->
        do_get_extensions(pubkey, @aex9_extensions_hash, "aex9_extensions", type_info)

      :aex141 ->
        do_get_extensions(pubkey, @aex141_extensions_hash, "aex141_extensions", type_info)
    end
  end

  @spec call_contract(pubkey(), Contract.method_name(), Contract.method_args()) ::
          {:ok, any()} | {:error, Runner.call_error()}
  def call_contract(contract_pk, method, args \\ []) do
    call_contract(contract_pk, method, args, Node.Db.top_height_hash(false))
  end

  @spec call_contract(
          pubkey(),
          Contract.method_name(),
          Contract.method_args(),
          block_hash() | height_hash()
        ) ::
          {:ok, any()} | {:error, term()}
  def call_contract(contract_pk, method, args, mb_hash) when is_binary(mb_hash) do
    case Node.Db.find_block_height(mb_hash) do
      {:ok, height} ->
        call_contract(contract_pk, method, args, {:micro, height, mb_hash})

      :none ->
        Log.warn("#{method} call error for #{encode_contract(contract_pk)}: block not found")
        {:error, :block_not_found}
    end
  end

  def call_contract(contract_pk, method, args, height_hash) do
    with {:error, reason} <- Runner.call_contract(contract_pk, height_hash, method, args) do
      Log.warn("#{method} call error for #{encode_contract(contract_pk)}: #{inspect(reason)}")
      {:error, reason}
    end
  end

  @spec event_name(AeMdw.Contracts.event_hash()) :: event_name() | nil
  def event_name(event_hash) do
    Node.aexn_event_names()
    |> Map.get(event_hash)
  end

  @spec valid_meta_info?(aexn_meta_info()) :: boolean()
  def valid_meta_info?(meta_info) do
    elem(meta_info, 0) not in [:format_error, :out_of_gas_error]
  end

  #
  # Private functions
  #
  defp do_get_extensions(
         pubkey,
         extensions_hash,
         extensions_function,
         {:fcode, functions, _hash_names, _hash}
       ) do
    case Map.get(functions, extensions_hash) do
      {[], {[], {:list, :string}}, %{0 => [RETURNR: {:immediate, extensions}]}} ->
        {:ok, extensions}

      {[], {[], {:list, :string}}, _other_code} ->
        with {:error, _reason} <- call_contract(pubkey, extensions_function) do
          :error
        end

      _mismatch ->
        :error
    end
  end

  defp decode_meta_info(:aex9, {name, symbol, decimals} = meta_info)
       when name > symbol and is_integer(decimals),
       do: meta_info

  defp decode_meta_info(:aex9, {symbol, name, decimals}) when is_integer(decimals),
    do: {name, symbol, decimals}

  defp decode_meta_info(:aex9, {name, decimals, symbol})
       when name > symbol and is_integer(decimals),
       do: {name, symbol, decimals}

  defp decode_meta_info(:aex9, {symbol, decimals, name}) when is_integer(decimals),
    do: {name, symbol, decimals}

  defp decode_meta_info(:aex9, {decimals, name, symbol})
       when name > symbol and is_integer(decimals),
       do: {name, symbol, decimals}

  defp decode_meta_info(:aex9, {decimals, symbol, name}) when is_integer(decimals),
    do: {name, symbol, decimals}

  defp decode_meta_info(:aex141, {name, symbol, variant1, variant2})
       when name > symbol and is_tuple(variant1) and is_tuple(variant2),
       do: decode_aex141_meta_info(name, symbol, variant1, variant2)

  defp decode_meta_info(:aex141, {name, variant1, symbol, variant2})
       when name > symbol and is_tuple(variant1) and is_tuple(variant2),
       do: decode_aex141_meta_info(name, symbol, variant1, variant2)

  defp decode_meta_info(:aex141, {name, variant1, variant2, symbol})
       when name > symbol and is_tuple(variant1) and is_tuple(variant2),
       do: decode_aex141_meta_info(name, symbol, variant1, variant2)

  defp decode_meta_info(:aex141, {variant1, name, variant2, symbol})
       when name > symbol and is_tuple(variant1) and is_tuple(variant2),
       do: decode_aex141_meta_info(name, symbol, variant1, variant2)

  defp decode_meta_info(:aex141, {variant1, variant2, name, symbol})
       when name > symbol and is_tuple(variant1) and is_tuple(variant2),
       do: decode_aex141_meta_info(name, symbol, variant1, variant2)

  defp decode_meta_info(:aex141, {symbol, name, variant1, variant2})
       when is_tuple(variant1) and is_tuple(variant2),
       do: decode_aex141_meta_info(name, symbol, variant1, variant2)

  defp decode_meta_info(:aex141, {symbol, variant1, name, variant2})
       when is_tuple(variant1) and is_tuple(variant2),
       do: decode_aex141_meta_info(name, symbol, variant1, variant2)

  defp decode_meta_info(:aex141, {symbol, variant1, variant2, name})
       when is_tuple(variant1) and is_tuple(variant2),
       do: decode_aex141_meta_info(name, symbol, variant1, variant2)

  defp decode_meta_info(:aex141, {variant1, symbol, name, variant2})
       when is_tuple(variant1) and is_tuple(variant2),
       do: decode_aex141_meta_info(name, symbol, variant1, variant2)

  defp decode_meta_info(:aex141, {variant1, symbol, variant2, name})
       when is_tuple(variant1) and is_tuple(variant2),
       do: decode_aex141_meta_info(name, symbol, variant1, variant2)

  defp decode_meta_info(:aex141, {variant1, variant2, symbol, name})
       when is_tuple(variant1) and is_tuple(variant2),
       do: decode_aex141_meta_info(name, symbol, variant1, variant2)

  defp decode_meta_info(aexn_type, _unknown), do: format_error_meta_info(aexn_type)

  defp decode_metadata_type(variant_type) do
    case variant_type do
      {:variant, [0, 0, 0, 0], 0, {}} -> :url
      {:variant, [0, 0, 0, 0], 1, {}} -> :ipfs
      {:variant, [0, 0, 0, 0], 2, {}} -> :object_id
      {:variant, [0, 0, 0, 0], 3, {}} -> :map
      {:variant, [0, 0, 0], 0, {}} -> :url
      {:variant, [0, 0, 0], 1, {}} -> :object_id
      {:variant, [0, 0, 0], 2, {}} -> :map
      _other -> :unknown
    end
  end

  defp decode_aex141_meta_info(name, symbol, variant1, variant2) do
    {variant_url, variant_type} = get_aex141_variants(variant1, variant2)

    url =
      case variant_url do
        {:variant, [0, 1], 1, {url}} -> url
        {:variant, [0, 1], 1, url} -> url
        _other -> nil
      end

    metadata_type = decode_metadata_type(variant_type)

    {name, symbol, url, metadata_type}
  end

  defp get_aex141_variants(variant1, variant2) do
    if match?({:variant, [0, 1], _idx, _url}, variant1) do
      {variant1, variant2}
    else
      {variant2, variant1}
    end
  end

  defp call_error_meta_info(:aex9), do: {:out_of_gas_error, :out_of_gas_error, nil}

  defp call_error_meta_info(:aex141),
    do: {:out_of_gas_error, :out_of_gas_error, :out_of_gas_error, nil}

  defp format_error_meta_info(:aex9), do: {:format_error, :format_error, nil}

  defp format_error_meta_info(:aex141),
    do: {:format_error, :format_error, :format_error, nil}

  defp has_all_signatures?(aexn_signatures, functions) do
    Enum.all?(aexn_signatures, fn {hash, type} ->
      match?({_code, ^type, _body}, Map.get(functions, hash))
    end)
  end

  # checked height aproximate to aex141 spec update
  defp get_aex141_signatures("ae_uat", height) when height < 673_800 do
    AeMdw.Node.previous_aex141_signatures()
  end

  defp get_aex141_signatures("ae_mainnet", height) when height < 669_300 do
    AeMdw.Node.previous_aex141_signatures()
  end

  defp get_aex141_signatures(_network, _height), do: AeMdw.Node.aex141_signatures()

  @option_string {:variant, [tuple: [], tuple: [:string]]}
  @option_metadata_spec {:variant,
                         [
                           tuple: [],
                           tuple: [variant: [tuple: [:string], tuple: [{:map, :string, :string}]]]
                         ]}
  @option_metadata_str {:variant, [tuple: [], tuple: [variant: [tuple: [:string]]]]}
  @option_metadata_map {:variant,
                        [tuple: [], tuple: [variant: [tuple: [{:map, :string, :string}]]]]}

  @metadata_hash <<99, 148, 233, 122>>
  @mint_hash <<207, 221, 154, 162>>
  @burn_hash <<177, 239, 193, 123>>
  @token_limit_hash <<161, 97, 56, 18>>
  @decrease_token_limit_hash <<97, 25, 71, 99>>

  defp valid_aex141_metadata?(functions) do
    with {_code, type, _body} <- Map.get(functions, @metadata_hash),
         {[:integer], metadata} <- type do
      valid_metadata?(metadata)
    else
      _nil_or_type_mismatch ->
        false
    end
  end

  defp valid_aex141_extension?("mintable", functions) do
    with {_code, type, _body} <- Map.get(functions, @mint_hash),
         {[:address, metadata, data], :integer} <- type do
      valid_metadata?(metadata) and data == @option_string
    else
      _nil_or_type_mismatch ->
        false
    end
  end

  defp valid_aex141_extension?("mintable_limit", functions) do
    with {_code, {[], :integer}, _body} <- Map.get(functions, @token_limit_hash),
         {_code, {[:integer], {:tuple, []}}, _body} <-
           Map.get(functions, @decrease_token_limit_hash) do
      true
    else
      _nil_or_mismatch ->
        false
    end
  end

  defp valid_aex141_extension?("burnable", functions) do
    match?({_code, {[:integer], {:tuple, []}}, _body}, functions[@burn_hash])
  end

  defp valid_aex141_extension?(_any, _functions), do: true

  defp valid_metadata?(metadata),
    do: metadata in [@option_metadata_spec, @option_metadata_str, @option_metadata_map]
end

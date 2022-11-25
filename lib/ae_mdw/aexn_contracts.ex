defmodule AeMdw.AexnContracts do
  @moduledoc """
  AEX-N detection and common calls to interact with the contract.
  """

  import AeMdwWeb.Helpers.AexnHelper, only: [enc_ct: 1]

  alias AeMdw.Contract
  alias AeMdw.Db.Model
  alias AeMdw.DryRun.Runner
  alias AeMdw.Node.Db, as: NodeDb
  alias AeMdw.Log

  @typep pubkey :: NodeDb.pubkey()
  @typep height :: AeMdw.Blocks.height()

  @max_height AeMdw.Util.max_int()

  @spec is_aex9?(pubkey() | Contract.type_info()) :: boolean()
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

  @spec is_aex141?(pubkey()) :: boolean()
  def is_aex141?(pubkey) when is_binary(pubkey) do
    with {:ok, {type_info, _compiler_vsn, _source_hash}} <- Contract.get_info(pubkey),
         true <- valid_aex141_signatures?(@max_height, type_info),
         {:ok, extensions} <- call_contract(pubkey, "aex141_extensions") do
      has_valid_aex141_extensions?(extensions, type_info)
    else
      _error_or_false ->
        false
    end
  end

  @spec has_aex141_signatures?(height(), pubkey()) :: boolean()
  def has_aex141_signatures?(height, pubkey) do
    case Contract.get_info(pubkey) do
      {:ok, {type_info, _compiler_vsn, _source_hash}} ->
        valid_aex141_signatures?(height, type_info)

      {:error, _reason} ->
        false
    end
  end

  @spec has_valid_aex141_extensions?(Model.aexn_extensions(), pubkey() | Contract.type_info()) ::
          boolean()
  def has_valid_aex141_extensions?(extensions, pubkey) when is_binary(pubkey) do
    case Contract.get_info(pubkey) do
      {:ok, {type_info, _compiler_vsn, _source_hash}} ->
        has_valid_aex141_extensions?(extensions, type_info)

      {:error, _reason} ->
        false
    end
  end

  def has_valid_aex141_extensions?(extensions, {:fcode, functions, _hash_names, _code}) do
    Enum.all?(extensions, &valid_aex141_extension?(&1, functions))
  end

  def has_valid_aex141_extensions?(_extensions, _no_fcode), do: false

  @spec call_meta_info(Model.aexn_type(), pubkey()) :: {:ok, Model.aexn_meta_info()}
  def call_meta_info(aexn_type, contract_pk) do
    case call_contract(contract_pk, "meta_info", []) do
      {:ok, {:tuple, meta_info_tuple}} ->
        {:ok, decode_meta_info(aexn_type, meta_info_tuple)}

      :error ->
        {:ok, call_error_meta_info(aexn_type)}
    end
  end

  @spec call_extensions(Model.aexn_type(), pubkey()) :: {:ok, Model.aexn_extensions()} | :error
  def call_extensions(aexn_type, pubkey) do
    case aexn_type do
      :aex9 -> call_contract(pubkey, "aex9_extensions")
      :aex141 -> call_contract(pubkey, "aex141_extensions")
    end
  end

  @spec call_contract(pubkey(), Contract.method_name(), Contract.method_args()) ::
          {:ok, any()} | :error
  def call_contract(contract_pk, method, args \\ []) do
    top_hash = NodeDb.top_height_hash(false)

    case Runner.call_contract(contract_pk, top_hash, method, args) do
      {:ok, return} ->
        {:ok, return}

      {:error, call_error} ->
        Log.warn("#{method} call error for #{enc_ct(contract_pk)}: #{inspect(call_error)}")
        :error
    end
  end

  #
  # Private functions
  #
  defp decode_meta_info(:aex9, {_name, _symbol, _decimals} = meta_info), do: meta_info

  defp decode_meta_info(:aex141, {name, symbol, variant_url, variant_type}) do
    url =
      case variant_url do
        {:variant, [0, 1], 1, {url}} -> url
        {:variant, [0, 1], 1, url} -> url
        _other -> nil
      end

    metadata_type = decode_metadata_type(variant_type)

    {name, symbol, url, metadata_type}
  end

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

  defp valid_aex141_signatures?(height, {:fcode, functions, _hash_names, _code}) do
    signatures = :aec_governance.get_network_id() |> get_aex141_signatures(height)

    has_all_signatures?(signatures, functions) and valid_aex141_metadata?(functions)
  end

  defp valid_aex141_signatures?(_height, _no_fcode), do: false

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

  defp valid_aex141_extension?("burnable", functions) do
    match?({_code, {[:integer], {:tuple, []}}, _body}, functions[@burn_hash])
  end

  defp valid_aex141_extension?(_any, _functions), do: true

  defp valid_metadata?(metadata),
    do: metadata in [@option_metadata_spec, @option_metadata_str, @option_metadata_map]
end

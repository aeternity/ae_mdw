defmodule AeMdw.AexnContracts do
  @moduledoc """
  AEX-N detection and common calls to interact with the contract.
  """

  import AeMdwWeb.Helpers.AexnHelper, only: [enc_ct: 1]

  alias AeMdw.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Node.Db, as: NodeDb
  alias AeMdw.Log

  @typep pubkey :: NodeDb.pubkey()

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
         true <- valid_aex141_signatures?(type_info),
         {:ok, extensions} <- call_contract(pubkey, "aex141_extensions") do
      has_valid_aex141_extensions?(extensions, type_info)
    else
      _error_or_false ->
        false
    end
  end

  @spec has_aex141_signatures?(pubkey()) :: boolean()
  def has_aex141_signatures?(pubkey) do
    case Contract.get_info(pubkey) do
      {:ok, {type_info, _compiler_vsn, _source_hash}} ->
        valid_aex141_signatures?(type_info)

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

  @spec call_meta_info(pubkey()) :: {:ok, Model.aexn_meta_info()} | :error
  def call_meta_info(contract_pk) do
    with {:ok, {:tuple, meta_info_tuple}} <- call_contract(contract_pk, "meta_info", []) do
      {:ok, decode_meta_info(meta_info_tuple)}
    end
  end

  @spec call_extensions(Model.aexn_type(), pubkey()) :: {:ok, Model.aexn_extensions()} | :error
  def call_extensions(aexn_type, pubkey) do
    case aexn_type do
      :aex9 -> call_contract(pubkey, "aex9_extensions")
      :aex141 -> call_contract(pubkey, "aex141_extensions")
    end
  end

  #
  # Private functions
  #
  defp call_contract(contract_pk, method, args \\ []) do
    top_hash = NodeDb.top_height_hash(false)

    case Contract.call_contract(contract_pk, top_hash, method, args) do
      {:ok, return} ->
        {:ok, return}

      {:error, call_error} ->
        Log.warn("#{method} call error for #{enc_ct(contract_pk)}: #{inspect(call_error)}")
        :error
    end
  end

  defp decode_meta_info({_name, _symbol, _decimals} = meta_info), do: meta_info

  defp decode_meta_info({name, symbol, variant_url, variant_type}) do
    url =
      case variant_url do
        {:variant, [0, 1], 1, {url}} -> url
        {:variant, [0, 1], 1, url} -> url
        _other -> nil
      end

    metadata_type =
      case variant_type do
        {:variant, [0, 0, 0, 0], 0, {}} -> :url
        {:variant, [0, 0, 0, 0], 1, {}} -> :ipfs
        {:variant, [0, 0, 0, 0], 2, {}} -> :object_id
        {:variant, [0, 0, 0, 0], 3, {}} -> :map
      end

    {name, symbol, url, metadata_type}
  end

  defp has_all_signatures?(aexn_signatures, functions) do
    Enum.all?(aexn_signatures, fn {hash, type} ->
      match?({_code, ^type, _body}, Map.get(functions, hash))
    end)
  end

  defp valid_aex141_signatures?({:fcode, functions, _hash_names, _code}) do
    valid_base_signatures? =
      AeMdw.Node.aex141_signatures()
      |> has_all_signatures?(functions)

    valid_base_signatures? and valid_aex141_metadata?(functions)
  end

  defp valid_aex141_signatures?(_no_fcode), do: false

  @option_string {:variant, [tuple: [], tuple: [:string]]}
  @option_metadata_map {:variant, [tuple: [], tuple: [{:map, :string, :string}]]}
  @metadata_hash <<99, 148, 233, 122>>
  @mint_hash <<207, 221, 154, 162>>
  @burn_hash <<177, 239, 193, 123>>
  @swap_hash <<17, 0, 79, 166>>
  @check_swap_hash <<214, 57, 13, 126>>
  @swapped_hash <<29, 236, 102, 255>>

  defp valid_aex141_metadata?(functions) do
    case Map.get(functions, @metadata_hash) do
      nil ->
        false

      {_code, type, _body} ->
        type == {[:integer], @option_string} or type == {[:integer], @option_metadata_map}
    end
  end

  defp valid_aex141_extension?("mintable", functions) do
    case Map.get(functions, @mint_hash) do
      nil ->
        false

      {_code, type, _body} ->
        type == {[:address, @option_string, @option_string], :integer} or
          type == {[:address, @option_metadata_map, @option_string], :integer}
    end
  end

  defp valid_aex141_extension?("burnable", functions) do
    match?({_code, {[:integer], {:tuple, []}}, _body}, functions[@burn_hash])
  end

  defp valid_aex141_extension?("swappable", functions) do
    match?({_code, {[], {:tuple, []}}, _body}, functions[@swap_hash]) and
      match?({_code, {[:address], :integer}, _body}, functions[@check_swap_hash]) and
      match?({_code, {[], {:map, :address, :string}}, _body}, functions[@swapped_hash])
  end

  defp valid_aex141_extension?(_any, _functions), do: false
end

defmodule AeMdw.Validate do
  @moduledoc false

  alias AeMdw.Node, as: AE
  alias AeMdw.Db.State
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Names
  alias :aeser_api_encoder, as: Enc

  @typep pubkey :: AE.Db.pubkey()
  @typep hash_str :: String.t()
  @typep hash_type :: :micro_block_hash | :key_block_hash
  @typep hash :: AE.Db.hash()
  @typep id :: String.t() | {:id, atom(), pubkey()} | Names.raw_data_pointer()
  @typep tx_type :: AE.tx_type()
  @typep tx_group :: AE.tx_group()
  @typep tx_field :: atom()
  @type block_index :: AeMdw.Blocks.block_index()

  @spec hash(hash_str(), hash_type()) :: {:ok, hash()} | {:error, {ErrInput.Hash, binary()}}
  def hash(hash_str, type) do
    with {:error, :invalid_encoding} <- Enc.safe_decode(type, hash_str) do
      {:error, {ErrInput.Hash, hash_str}}
    end
  end

  @spec id(id()) :: {:ok, pubkey()} | {:error, {ErrInput.Id, binary()}}
  def id(<<_pk::256>> = id),
    do: {:ok, id}

  def id(<<_prefix::2-binary, "_", _pk::binary>> = id) do
    try do
      {_id_type, pk} = Enc.decode(id)
      {:ok, pk}
    rescue
      _error -> {:error, {ErrInput.Id, id}}
    end
  end

  def id({:id, _tag, <<_pk::256>> = pk}),
    do: {:ok, pk}

  def id({:data, pk}) when is_binary(pk),
    do: {:ok, pk}

  def id(id),
    do: {:error, {ErrInput.Id, id}}

  @spec id!(id()) :: pubkey()
  def id!(id), do: unwrap!(&id/1, id)

  @spec id(id(), [atom()]) :: {:ok, pubkey()} | {:error, {ErrInput.Id, binary()}}
  def id(<<prefix::2-binary, "_", _pk::binary>> = ident, [_type1 | _rest_types] = allowed_types) do
    case prefix in AE.id_prefixes() do
      true ->
        case Enc.safe_decode({:id_hash, allowed_types}, ident) do
          {:ok, id} ->
            id(id)

          {:error, _reason} ->
            {:error, {ErrInput.Id, ident}}
        end

      false ->
        {:error, {ErrInput.Id, ident}}
    end
  end

  def id({:id, hash_type, <<_pk::256>> = pk} = id, [_type1 | _rest_types] = allowed_types),
    do: (AE.id_type(hash_type) in allowed_types && {:ok, pk}) || {:error, {ErrInput.Id, id}}

  def id(<<_pk::256>> = pk, [_type1 | _rest_types] = _allowed_types),
    do: {:ok, pk}

  def id(id, _allowed_types),
    do: {:error, {ErrInput.Id, id}}

  @spec id!(id(), [atom()]) :: pubkey()
  def id!(id, allowed_types), do: unwrap!(&id(&1, allowed_types), id)

  @spec optional_id(id() | nil, [atom()]) :: {:ok, pubkey() | nil} | {:error, {ErrInput.Id, id()}}
  def optional_id(nil, _types), do: {:ok, nil}
  def optional_id(id, allowed_types), do: id(id, allowed_types)

  @spec name_id(id()) :: {:ok, pubkey()} | {:error, {ErrInput.Id, id()}}
  def name_id(name_ident) do
    with {:error, {_ex, ^name_ident}} = error <- id(name_ident) do
      ident = ensure_name_suffix(name_ident)

      case :aens.get_name_hash(ident) do
        {:ok, pk} -> {:ok, pk}
        _invalid -> error
      end
    end
  end

  @spec name_id!(id()) :: pubkey()
  def name_id!(name_ident), do: unwrap!(&name_id/1, name_ident)

  @spec plain_name(State.t(), String.t()) ::
          {:ok, pubkey()} | {:error, {ErrInput.t(), String.t()}}
  def plain_name(state, name_ident) do
    case id(name_ident) do
      {:ok, name_hash} ->
        case AeMdw.Db.Name.plain_name(state, name_hash) do
          {:ok, plain_name} -> {:ok, plain_name}
          nil -> {:error, {ErrInput.NotFound, name_ident}}
        end

      {:error, _reason} ->
        if is_binary(name_ident) and name_ident != "" and String.printable?(name_ident) do
          {:ok, String.downcase(ensure_name_suffix(name_ident))}
        else
          {:error, {ErrInput.Id, name_ident}}
        end
    end
  end

  @spec plain_name!(State.t(), String.t()) :: pubkey()
  def plain_name!(state, name_ident), do: unwrap!(&plain_name(state, &1), name_ident)

  @spec tx_type(tx_type() | binary()) :: {:ok, tx_type()} | {:error, ErrInput.t()}
  def tx_type(type) when is_atom(type),
    do: (type in AE.tx_types() && {:ok, type}) || {:error, ErrInput.TxType.exception(value: type)}

  def tx_type(type) when is_binary(type) do
    try do
      tx_type(String.to_existing_atom(type <> "_tx"))
    rescue
      ArgumentError ->
        {:error, ErrInput.TxType.exception(value: type)}
    end
  end

  @spec tx_group(tx_group() | binary()) :: {:ok, tx_group()} | {:error, ErrInput.t()}
  def tx_group(group) when is_atom(group),
    do: (group in AE.tx_groups() && {:ok, group}) || {:error, {ErrInput.TxGroup, group}}

  def tx_group(group) when is_binary(group) do
    try do
      tx_group(String.to_existing_atom(group))
    rescue
      ArgumentError ->
        {:error, ErrInput.TxGroup.exception(value: group)}
    end
  end

  @spec tx_field(tx_field() | binary()) :: {:ok, tx_field()} | {:error, ErrInput.t()}
  def tx_field(field) when is_binary(field),
    do:
      (field in AE.id_fields() &&
         {:ok, String.to_existing_atom(field)}) ||
        {:error, ErrInput.TxField.exception(value: field)}

  def tx_field(field) when is_atom(field),
    do: tx_field(Atom.to_string(field))

  def tx_field(field),
    do: {:error, ErrInput.TxField.exception(value: field)}

  @spec nonneg_int(integer() | binary()) ::
          {:ok, non_neg_integer()} | {:error, {ErrInput.reason(), any()}}
  def nonneg_int(s) when is_binary(s) do
    case Integer.parse(s, 10) do
      {i, ""} when i >= 0 -> {:ok, i}
      _error_or_invalid -> {:error, {ErrInput.NonnegInt, s}}
    end
  end

  def nonneg_int(x) when is_integer(x) and x >= 0, do: {:ok, x}
  def nonneg_int(x), do: {:error, {ErrInput.NonnegInt, x}}

  @spec block_index(binary()) :: {:ok, block_index()} | {:error, {ErrInput.BlockIndex, binary()}}
  def block_index(x) when is_binary(x) do
    case String.split(x, ["/"]) do
      [kbi, mbi] when mbi != "-1" ->
        with {:ok, kbi} <- nonneg_int(kbi),
             {:ok, mbi} <- nonneg_int(mbi) do
          {:ok, {kbi, mbi}}
        else
          _invalid ->
            {:error, {ErrInput.BlockIndex, x}}
        end

      list ->
        with [kbi | rem] when rem in [[], ["-1"]] <- list,
             {:ok, kbi} <- nonneg_int(kbi) do
          {:ok, {kbi, -1}}
        else
          _invalid ->
            {:error, {ErrInput.BlockIndex, x}}
        end
    end
  end

  @spec ensure_name_suffix(String.t()) :: String.t()
  def ensure_name_suffix(<<"nm_", _rest::binary>> = id), do: id

  def ensure_name_suffix(ident) when is_binary(ident) do
    if String.ends_with?(ident, [".chain", ".test"]) do
      ident
    else
      ident <> ".chain"
    end
  end

  defp unwrap!(validator, value) do
    case validator.(value) do
      {:ok, res} ->
        res

      {:error, {ex, ^value}} ->
        raise ex, value: value

      {:error, exception} ->
        raise exception
    end
  end
end

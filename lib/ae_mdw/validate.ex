defmodule AeMdw.Validate do
  alias AeMdw.Node, as: AE
  alias AeMdw.Error.Input, as: ErrInput
  alias :aeser_api_encoder, as: Enc

  # returns pubkey
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

  def id(id),
    do: {:error, {ErrInput.Id, id}}

  def id!(id), do: unwrap!(&id/1, id)

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

  def id!(id, allowed_types), do: unwrap!(&id(&1, allowed_types), id)

  #

  def name_id(name_ident) do
    with {:ok, pk} <- id(name_ident) do
      {:ok, pk}
    else
      {:error, {_ex, ^name_ident}} = error ->
        ident = ensure_name_suffix(name_ident)

        case :aens.get_name_hash(ident) do
          {:ok, pk} -> {:ok, pk}
          _invalid -> error
        end
    end
  end

  def name_id!(name_ident), do: unwrap!(&name_id/1, name_ident)

  def plain_name(state, name_ident) do
    case id(name_ident) do
      {:ok, name_hash} ->
        case AeMdw.Db.Name.plain_name(state, name_hash) do
          {:ok, plain_name} -> {:ok, plain_name}
          nil -> {:error, {ErrInput.NotFound, name_ident}}
        end

      _error ->
        ok? = is_binary(name_ident) and name_ident != "" and String.printable?(name_ident)

        case ok? do
          true ->
            {:ok, String.downcase(ensure_name_suffix(name_ident))}

          false ->
            {:error, {ErrInput.Id, name_ident}}
        end
    end
  end

  def plain_name!(state, name_ident), do: unwrap!(&plain_name(state, &1), name_ident)

  # returns transaction type (atom)
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

  def tx_field(field) when is_binary(field),
    do:
      (field in AE.id_fields() &&
         {:ok, String.to_existing_atom(field)}) ||
        {:error, ErrInput.TxField.exception(value: field)}

  def tx_field(field) when is_atom(field),
    do: tx_field(Atom.to_string(field))

  def tx_field(field),
    do: {:error, ErrInput.TxField.exception(value: field)}

  def nonneg_int(s) when is_binary(s) do
    case Integer.parse(s, 10) do
      {i, ""} when i >= 0 -> {:ok, i}
      _error_or_invalid -> {:error, {ErrInput.NonnegInt, s}}
    end
  end

  def nonneg_int(x) when is_integer(x) and x >= 0, do: {:ok, x}
  def nonneg_int(x), do: {:error, {ErrInput.NonnegInt, x}}

  def block_index(x) when is_binary(x) do
    map_nni = fn s, f ->
      case nonneg_int(s) do
        {:ok, i} -> f.(i)
        _error -> {:error, {ErrInput.BlockIndex, x}}
      end
    end

    case String.split(x, ["/"]) do
      [kbi, mbi] when mbi != "-1" ->
        with {:ok, kbi} <- map_nni.(kbi, &{:ok, &1}),
             {:ok, mbi} <- map_nni.(mbi, &{:ok, &1}) do
          {:ok, {kbi, mbi}}
        else
          _invalid ->
            {:error, {ErrInput.BlockIndex, x}}
        end

      [kbi | rem] when rem in [[], ["-1"]] ->
        map_nni.(kbi, &{:ok, {&1, -1}})

      _invalid ->
        {:error, {ErrInput.BlockIndex, x}}
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

  def ensure_name_suffix(ident) when is_binary(ident),
    do: (String.ends_with?(ident, [".chain", ".test"]) && ident) || ident <> ".chain"
end

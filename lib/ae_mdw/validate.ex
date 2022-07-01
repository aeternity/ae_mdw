defmodule AeMdw.Validate do
  alias AeMdw.Node, as: AE
  alias AeMdw.Error.Input, as: ErrInput
  alias :aeser_api_encoder, as: Enc

  # returns pubkey
  def id(<<_::256>> = id),
    do: {:ok, id}

  def id(<<_prefix::2-binary, "_", _::binary>> = id) do
    try do
      {_id_type, pk} = Enc.decode(id)
      {:ok, pk}
    rescue
      _ -> {:error, {ErrInput.Id, id}}
    end
  end

  def id({:id, _, <<_::256>> = pk}),
    do: {:ok, pk}

  def id(id),
    do: {:error, {ErrInput.Id, id}}

  def id!(id), do: unwrap!(&id/1, id)

  def id(<<prefix::2-binary, "_", _::binary>> = ident, [_ | _] = allowed_types) do
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

  def id({:id, hash_type, <<_::256>> = pk} = id, [_ | _] = allowed_types),
    do: (AE.id_type(hash_type) in allowed_types && {:ok, pk}) || {:error, {ErrInput.Id, id}}

  def id(<<_::256>> = pk, [_ | _] = _allowed_types),
    do: {:ok, pk}

  def id(id, _),
    do: {:error, {ErrInput.Id, id}}

  def id!(id, allowed_types), do: unwrap!(&id(&1, allowed_types), id)

  #

  def name_id(name_ident) do
    with {:ok, pk} <- id(name_ident) do
      {:ok, pk}
    else
      {:error, {_ex, ^name_ident}} = error ->
        ident = ensure_name_suffix(name_ident)

        with {:ok, pk} <- :aens.get_name_hash(ident) do
          {:ok, pk}
        else
          _ -> error
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

      _ ->
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
    do: (type in AE.tx_types() && {:ok, type}) || {:error, {ErrInput.TxType, type}}

  def tx_type(type) when is_binary(type) do
    try do
      tx_type(String.to_existing_atom(type <> "_tx"))
    rescue
      ArgumentError ->
        {:error, {ErrInput.TxType, type}}
    end
  end

  def tx_type!(type),
    do: unwrap!(&tx_type/1, type)

  def tx_group(group) when is_atom(group),
    do: (group in AE.tx_groups() && {:ok, group}) || {:error, {ErrInput.TxGroup, group}}

  def tx_group(group) when is_binary(group) do
    try do
      tx_group(String.to_existing_atom(group))
    rescue
      ArgumentError ->
        {:error, {ErrInput.TxGroup, group}}
    end
  end

  def tx_group!(group),
    do: unwrap!(&tx_group/1, group)

  def tx_field(field) when is_binary(field),
    do:
      (field in AE.id_fields() &&
         {:ok, String.to_existing_atom(field)}) ||
        {:error, {ErrInput.TxField, field}}

  def tx_field(field) when is_atom(field),
    do: tx_field(Atom.to_string(field))

  def tx_field(field),
    do: {:error, {ErrInput.TxField, field}}

  def tx_field!(field),
    do: unwrap!(&tx_field/1, field)

  def nonneg_int(s) when is_binary(s) do
    case Integer.parse(s, 10) do
      {i, ""} when i >= 0 -> {:ok, i}
      _ -> {:error, {ErrInput.NonnegInt, s}}
    end
  end

  def nonneg_int(x) when is_integer(x) and x >= 0, do: {:ok, x}
  def nonneg_int(x), do: {:error, {ErrInput.NonnegInt, x}}

  def nonneg_int!(x),
    do: unwrap!(&nonneg_int/1, x)

  def block_index(x) when is_binary(x) do
    map_nni = fn s, f ->
      case nonneg_int(s) do
        {:ok, i} -> f.(i)
        _ -> {:error, {ErrInput.BlockIndex, x}}
      end
    end

    case String.split(x, ["/"]) do
      [kbi, mbi] when mbi != "-1" ->
        with {:ok, kbi} <- map_nni.(kbi, &{:ok, &1}),
             {:ok, mbi} <- map_nni.(mbi, &{:ok, &1}) do
          {:ok, {kbi, mbi}}
        else
          _ ->
            {:error, {ErrInput.BlockIndex, x}}
        end

      [kbi | rem] when rem in [[], ["-1"]] ->
        map_nni.(kbi, &{:ok, {&1, -1}})

      _ ->
        {:error, {ErrInput.BlockIndex, x}}
    end
  end

  def block_index!(x),
    do: unwrap!(&block_index/1, x)

  def base64(x) when is_binary(x) do
    case Base.decode64(x) do
      {:ok, bin} ->
        {:ok, bin}

      :error ->
        {:error, {ErrInput.Base64, x}}
    end
  end

  def base64!(x) when is_binary(x),
    do: unwrap!(&base64/1, x)

  def hex32(x) when is_binary(x) do
    case Base.hex_decode32(x) do
      {:ok, bin} ->
        {:ok, bin}

      :error ->
        {:error, {ErrInput.Hex32, x}}
    end
  end

  def hex32!(x) when is_binary(x),
    do: unwrap!(&hex32/1, x)

  defp unwrap!(validator, value) do
    case validator.(value) do
      {:ok, res} ->
        res

      {:error, {ex, ^value}} ->
        raise ex, value: value
    end
  end

  def ensure_name_suffix(ident) when is_binary(ident),
    do: (String.ends_with?(ident, [".chain", ".test"]) && ident) || ident <> ".chain"
end

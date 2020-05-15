defmodule AeMdw.Validate do
  alias AeMdw.Node, as: AE
  alias AeMdw.Error.Input, as: ErrInput
  alias :aeser_api_encoder, as: Enc

  # returns pubkey
  def id(<<_prefix::2-binary, "_", _::binary>> = id) do
    try do
      {_id_type, pk} = Enc.decode(id)
      {:ok, pk}
    rescue
      _ -> {:error, {ErrInput.Id, id}}
    end
  end

  def id(<<_::256>> = id),
    do: {:ok, id}

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

  def id(id, _),
    do: {:error, {ErrInput.Id, id}}

  def id!(id, allowed_types), do: unwrap!(&id(&1, allowed_types), id)

  # returns transaction type (atom)
  def tx_type(type) when is_atom(type),
    do: (type in AE.tx_types() && {:ok, type}) || {:error, {ErrInput.TxType, type}}

  def tx_type(type) when is_binary(type) do
    try do
      tx_type(String.to_existing_atom(type))
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

  defp unwrap!(validator, value) do
    case validator.(value) do
      {:ok, res} -> res
      {:error, {ex, ^value}} -> raise ex, value: value
    end
  end
end

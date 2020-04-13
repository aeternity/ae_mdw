defmodule AeMdw.Validate do
  alias AeMdw.Node, as: AE
  alias AeMdw.Error.Input, as: ErrInput
  alias :aeser_api_encoder, as: Enc

  # returns pubkey
  def id(<<prefix::2-binary, "_", _::binary>> = id) do
    case prefix in AE.id_prefixes() do
      true ->
        {_id_type, pk} = Enc.decode(id)
        {:ok, pk}
      false ->
        {:error, {ErrInput.Id, id}}
    end
  end
  def id(<<_::256>> = id),
    do: {:ok, id}
  def id({:id, _, <<_::256>> = pk}),
    do: {:ok, pk}
  def id(id),
    do: {:error, {ErrInput.Id, id}}

  def id!(id), do: unwrap!(&id/1, id)


  def id(<<prefix::2-binary, "_", _::binary>> = ident, [_|_] = allowed_types) do
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
  def id({:id, hash_type, <<_::256>> = pk} = id, [_|_] = allowed_types),
    do: AE.id_type(hash_type) in allowed_types && {:ok, pk} || {:error, {ErrInput.Id, id}}
  def id(id, _),
    do: {:error, {ErrInput.Id, id}}

  def id!(id, allowed_types), do: unwrap!(&id(&1, allowed_types), id)

  # returns transaction type (atom)
  def tx_type(type) when is_atom(type),
    do: type in AE.tx_types && {:ok, type} || {:error, {ErrInput.TxType, type}}
  def tx_type(type) when is_binary(type) do
    case type in AE.tx_names do
      true -> {:ok, AE.tx_type(type)}
      false -> {:error, {ErrInput.TxType, type}}
    end
  end

  def tx_type!(type),
    do: unwrap!(&tx_type/1, type)

  defp unwrap!(validator, value) do
    case validator.(value) do
      {:ok, res} -> res
      {:error, {ex, ^value}} -> raise ex, value: value
    end
  end

end

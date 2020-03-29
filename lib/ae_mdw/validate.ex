defmodule AeMdw.Validate do
  alias AeMdw.Node, as: AE
  alias AeMdw.Error.Input, as: ErrInput

  # returns pubkey
  def id(<<prefix::2, "_", _::binary>> = id) do
    case prefix in AE.id_prefixes() do
      true ->
        {_id_type, pk} = :aeser_api_encoder.decode(id)
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

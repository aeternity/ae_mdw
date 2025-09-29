defmodule AeMdwWeb.GraphQL.Resolvers.ContractResolver do
  @moduledoc """
  Contract-related GraphQL resolvers.
  """
  alias AeMdw.Db.{State, Model, Contract}
  require Model

  @spec contract(any, %{id: String.t()}, Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def contract(_parent, %{id: contract_pk_enc}, %{context: ctx}) do
    with {:ok, contract_pk} <- decode_pk(contract_pk_enc),
         {:ok, state} <- fetch_state(ctx) do
      aexn_type = Contract.get_aexn_type(state, contract_pk)

      meta =
        case aexn_type do
          nil -> {nil, nil}
          type -> fetch_meta(state, type, contract_pk)
        end

      {name, symbol} = meta

      {:ok,
       %{
         id: contract_pk_enc,
         aexn_type: aexn_type && Atom.to_string(aexn_type),
         meta_name: name,
         meta_symbol: symbol
       }}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "not_found"}
    end
  end

  defp fetch_state(%{state: %State{} = state}), do: {:ok, state}
  defp fetch_state(_), do: {:error, "partial_state_unavailable"}

  defp decode_pk(<<"ct_"::binary, _rest::binary>> = encoded) do
    case :aeser_api_encoder.safe_decode(:contract_pubkey, encoded) do
      {:ok, bin} -> {:ok, bin}
      {:error, _} -> {:error, "invalid_contract_id"}
    end
  end
  defp decode_pk(_), do: {:error, "invalid_contract_id"}

  defp fetch_meta(state, aexn_type, contract_pk) do
    # Access internal state directly; replicating logic from DB layers for meta extraction.
    case State.get(state, Model.AexnContract, {aexn_type, contract_pk}) do
      {:ok, m} ->
        m |> Model.aexn_contract(:meta_info) |> handle_meta()
      :not_found -> {nil, nil}
    end
  end

  defp handle_meta({name, symbol, _decimals, _version}), do: {name, symbol}
  defp handle_meta(_), do: {nil, nil}
end

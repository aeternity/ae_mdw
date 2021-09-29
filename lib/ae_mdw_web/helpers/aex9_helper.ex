defmodule AeMdwWeb.Helpers.Aex9Helper do
  @moduledoc """
  Used to format aex9 related info
  """

  @typep top_height_hash() :: {atom(), pos_integer(), binary()}

  alias AeMdw.Node.Db, as: DBN

  @spec normalize_balances(map()) :: map()
  def normalize_balances(bals) do
    for {{:address, pk}, amt} <- bals, reduce: %{} do
      acc ->
        Map.put(acc, enc_id(pk), amt)
    end
  end

  @spec enc_block(atom(), binary()) :: String.t()
  def enc_block(:key, hash), do: :aeser_api_encoder.encode(:key_block_hash, hash)
  def enc_block(:micro, hash), do: :aeser_api_encoder.encode(:micro_block_hash, hash)

  @spec enc_ct(binary()) :: String.t()
  def enc_ct(pk), do: :aeser_api_encoder.encode(:contract_pubkey, pk)

  @spec enc_id(binary()) :: String.t()
  def enc_id(pk), do: :aeser_api_encoder.encode(:account_pubkey, pk)

  @spec enc(atom(), binary()) :: String.t()
  def enc(type, pk), do: :aeser_api_encoder.encode(type, pk)

  @spec safe_aex9_balances(binary()) :: {map(), top_height_hash()}
  def safe_aex9_balances(contract_pk),
    do: safe_aex9_balances(contract_pk, DBN.top_height_hash(false))

  @spec safe_aex9_balances(binary(), top_height_hash()) :: {map(), top_height_hash()}
  def safe_aex9_balances(contract_pk, {type, height, hash}) do
    with {:ok, addr_map} <-
           AeMdw.Contract.call_contract(
             contract_pk,
             {type, height, hash},
             "balances",
             []
           ) do
      {addr_map, {type, height, hash}}
    else
      {:error, "Out of gas"} ->
        IO.puts("Out of gas for #{:aeser_api_encoder.encode(:contract_pubkey, contract_pk)}")
        {%{}, nil}
    end
  end
end

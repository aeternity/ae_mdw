defmodule AeMdwWeb.Helpers.AexnHelper do
  @moduledoc """
  Used to format aex9 related info
  """

  @max_sort_field_length 100

  @typep pubkey() :: <<_::256>>

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

  @spec enc_ct(pubkey()) :: String.t()
  def enc_ct(pk), do: :aeser_api_encoder.encode(:contract_pubkey, pk)

  @spec enc_id(pubkey()) :: String.t()
  def enc_id(pk), do: :aeser_api_encoder.encode(:account_pubkey, pk)

  @spec sort_field_truncate(String.t() | :atom) :: String.t()
  def sort_field_truncate(field_value) when is_atom(field_value), do: field_value

  def sort_field_truncate(field_value) do
    if String.length(field_value) <= @max_sort_field_length do
      field_value
    else
      String.slice(field_value, 0, @max_sort_field_length) <> "..."
    end
  end

  @spec enc(atom(), pubkey()) :: String.t()
  defdelegate enc(type, pk), to: :aeser_api_encoder, as: :encode
end

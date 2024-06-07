defmodule AeMdwWeb.Helpers.AexnHelper do
  @moduledoc """
  Helper functions for AEX-9 and AEX-141
  """

  import AeMdw.Util.Encoding, only: [encode_account: 1]

  @max_sort_field_length 100

  @spec normalize_balances(map()) :: map()
  def normalize_balances(bals) do
    for {{:address, pk}, amt} <- bals, reduce: %{} do
      acc ->
        Map.put(acc, encode_account(pk), amt)
    end
  end

  @spec sort_field_truncate(String.t() | atom()) :: String.t()
  def sort_field_truncate(field_value) when is_atom(field_value), do: field_value

  def sort_field_truncate(field_value) do
    if String.length(field_value) <= @max_sort_field_length do
      field_value
    else
      String.slice(field_value, 0, @max_sort_field_length) <> "..."
    end
  end
end

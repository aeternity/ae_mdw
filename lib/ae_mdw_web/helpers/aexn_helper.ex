defmodule AeMdwWeb.Helpers.AexnHelper do
  @moduledoc """
  Helper functions for AEX-9 and AEX-141
  """

  alias AeMdw.AexnContracts
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Validate

  import AeMdw.Util.Encoding, only: [encode_account: 1]

  @max_sort_field_length 100

  @typep pubkey() :: <<_::256>>

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

  @spec validate_aex9(String.t(), State.t()) :: {:ok, pubkey()} | {:error, Error.t()}
  def validate_aex9(contract_id, state) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:not_aex9, true} <- {:not_aex9, AexnContracts.is_aex9?(contract_pk)},
         {:invalid, false} <-
           {:invalid, State.exists?(state, Model.Aex9InvalidContract, contract_pk)} do
      {:ok, contract_pk}
    else
      {:error, reason} ->
        {:error, reason}

      {:not_aex9, false} ->
        {:error, ErrInput.NotAex9.exception(value: contract_id)}

      {:invalid, true} ->
        {:error, ErrInput.AexnContractInvalid.exception(value: contract_id)}
    end
  end
end

defmodule AeMdw.Db.Stream.Query.Parser do
  @moduledoc false
  alias AeMdw.Error
  alias AeMdw.Node, as: AE
  alias AeMdw.Validate
  alias AeMdw.Error.Input, as: ErrInput

  @type validate_func :: (String.t() -> binary())

  @spec classify_ident(String.t()) :: validate_func()
  def classify_ident("account"), do: &Validate.id!(&1, [:account_pubkey])
  def classify_ident("contract"), do: &Validate.id!(&1, [:contract_pubkey])
  def classify_ident("channel"), do: &Validate.id!(&1, [:channel])
  def classify_ident("oracle"), do: &Validate.id!(&1, [:oracle_pubkey])
  def classify_ident("name"), do: &Validate.name_id!/1
  def classify_ident(_ident), do: &Validate.id!/1

  @spec parse_field(String.t()) :: {:ok, map()} | {:error, Error.t()}
  def parse_field(field) do
    case String.split(field, ["."]) do
      [field] ->
        with {:ok, field} <- Validate.tx_field(field) do
          tx_types_poss =
            for tx_type <- field_types(field),
                reduce: %{},
                do: (acc -> add_pos(acc, tx_type, field))

          {:ok, tx_types_poss}
        end

      [type_no_suffix, field] ->
        with {:ok, tx_type} <- Validate.tx_type(type_no_suffix),
             {:ok, field} <- Validate.tx_field(field) do
          if tx_type in field_types(field) do
            {:ok, add_pos(%{}, tx_type, field)}
          else
            {:error, ErrInput.TxField.exception(value: field)}
          end
        end

      _invalid ->
        {:error, ErrInput.TxField.exception(value: field)}
    end
  end

  @spec field_types(atom()) :: MapSet.t()
  def field_types(field) do
    base_types = AE.tx_field_types(field)

    case field do
      :contract_id ->
        base_types
        |> MapSet.put(:contract_create_tx)
        |> MapSet.put(:ga_attach_tx)

      :channel_id ->
        MapSet.put(base_types, :channel_create_tx)

      :oracle_id ->
        MapSet.put(base_types, :oracle_register_tx)

      :name_id ->
        MapSet.put(base_types, :name_claim_tx)

      _field_type ->
        base_types
    end
  end

  defp add_pos(acc, type, field), do: Map.put(acc, type, [AE.tx_ids(type)[field]])
end

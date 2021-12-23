defmodule AeMdw.Db.Stream.Query.Parser do
  # credo:disable-for-this-file
  alias AeMdw.Node, as: AE
  alias AeMdw.Validate
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Db.Stream.Query.Util, as: QUtil

  # import AeMdwWeb.Util

  ##########

  def classify_ident("account"), do: {false, &Validate.id!(&1, [:account_pubkey])}
  def classify_ident("contract"), do: {false, &Validate.id!(&1, [:contract_pubkey])}
  def classify_ident("channel"), do: {false, &Validate.id!(&1, [:channel])}
  def classify_ident("oracle"), do: {false, &Validate.id!(&1, [:oracle_pubkey])}
  def classify_ident("name"), do: {false, &Validate.name_id!/1}
  def classify_ident(_ident), do: {true, &Validate.id!/1}

  def id_tx_types("account"), do: AE.tx_types()
  def id_tx_types("contract"), do: AE.tx_group(:contract)
  def id_tx_types("channel"), do: AE.tx_group(:channel)
  def id_tx_types("oracle"), do: AE.tx_group(:oracle)
  def id_tx_types("name"), do: AE.tx_group(:name)

  def parse(query_groups) when is_map(query_groups) do
    types = parse_types(query_groups)
    id_groups = Map.drop(query_groups, ["type", "type_group"])

    ids =
      Enum.reduce(id_groups, %{}, fn {param, elts}, acc ->
        {field?, pk_validator} = classify_ident(param)
        pks = Enum.map(elts, pk_validator)

        positions =
          case field? do
            false ->
              for type <- id_tx_types(param), into: %{}, do: {type, QUtil.tx_positions(type)}

            true ->
              parse_field(param)
          end

        Map.put(acc, param, {Enum.uniq(pks), positions})
      end)

    {ids, types}
  end

  def parse(_query_groups) do
    {%{}, MapSet.new()}
  end

  ##########

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

      _ ->
        base_types
    end
  end

  def parse_field(field) do
    add_pos = fn acc, type, field -> Map.put(acc, type, [AE.tx_ids(type)[field]]) end

    case String.split(field, ["."]) do
      [field] ->
        field = Validate.tx_field!(field)
        for tx_type <- field_types(field), reduce: %{}, do: (acc -> add_pos.(acc, tx_type, field))

      [type_no_suffix, field] ->
        tx_type = Validate.tx_type!(type_no_suffix)
        field = Validate.tx_field!(field)
        tx_type in field_types(field) || raise ErrInput.TxField, value: field
        add_pos.(%{}, tx_type, field)

      _ ->
        raise ErrInput.TxField, value: field
    end
  end

  def parse_types(%{"type" => [_ | _] = types, "type_group" => [_ | _] = type_groups}) do
    from_types = types |> Enum.map(&Validate.tx_type!(&1)) |> MapSet.new()
    from_groups = type_groups |> Enum.flat_map(&expand_tx_group(&1)) |> MapSet.new()
    MapSet.union(from_types, from_groups)
  end

  def parse_types(%{"type_group" => [_ | _] = txgs}),
    do: txgs |> Enum.flat_map(&expand_tx_group(&1)) |> MapSet.new()

  def parse_types(%{"type" => [_ | _] = types}),
    do: types |> Enum.map(&Validate.tx_type!(&1)) |> MapSet.new()

  def parse_types(%{}),
    do: MapSet.new()

  defp expand_tx_group(group),
    do: AeMdw.Node.tx_group(Validate.tx_group!(group))

  ##########

  # def t() do
  #   "spend.sender_id=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&recipient_id=ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR&contract=ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z&type_group=channel"
  #   |> parse
  # end
end

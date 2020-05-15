defmodule AeMdwWeb.Validate do
  alias AeMdw.Node, as: AE
  alias AeMdw.Validate
  alias AeMdw.Error.Input, as: ErrInput

  import AeMdw.Util

  @id_pk_types %{"account" => :account_pubkey}

  ##########

  def parse_field(field) do
    case String.split(field, ["."]) do
      [field] ->
        field = Validate.tx_field!(field)

        type_pos =
          Enum.reduce(AE.tx_types(), %{}, fn tx_type, acc ->
            case AE.tx_ids(tx_type)[field] do
              nil -> acc
              pos -> Map.put(acc, tx_type, pos)
            end
          end)

        {field, type_pos}

      [prefix, field] ->
        tx_type = prefix <> "_tx"
        field = Validate.tx_field!(field)
        prefix in AE.tx_prefixes() || raise ErrInput.TxType, value: tx_type
        tx_type = String.to_existing_atom(tx_type)

        field_pos =
          AE.id_field_type(field)[tx_type] ||
            raise ErrInput.TxField, value: "#{field} not found in #{tx_type}"

        {field, %{tx_type => field_pos}}

      _ ->
        raise ErrInput.TxField, value: field
    end
  end

  def ids(%{} = req) do
    for {key, maybe_ids} <- req, reduce: {MapSet.new(), %{}} do
      {untyped, typed} ->
        case @id_pk_types[key] do
          nil ->
            {field, type_pos_map} = parse_field(key)

            {untyped,
             for maybe_id <- maybe_ids, reduce: typed do
               acc ->
                 id = Validate.id!(maybe_id)

                 for {type, pos} <- type_pos_map,
                     reduce: acc,
                     do: (acc -> Map.put(acc, {type, field, id}, pos))
             end}

          pk_type ->
            parsed_ids = Enum.map(maybe_ids, &Validate.id!(&1, [pk_type])) |> MapSet.new()
            {MapSet.union(untyped, parsed_ids), typed}
        end
    end
  end

  def tx_types(%{"type" => [_ | _] = types, "type_group" => [_ | _] = type_groups} = req) do
    from_types = types |> Enum.map(&Validate.tx_type!(&1)) |> MapSet.new()
    from_groups = type_groups |> Enum.flat_map(&expand_tx_group(&1)) |> MapSet.new()
    MapSet.union(from_types, from_groups)
  end

  def tx_types(%{"type_group" => [_ | _] = txgs} = req),
    do: txgs |> Enum.flat_map(&expand_tx_group(&1)) |> MapSet.new()

  def tx_types(%{"type" => [_ | _] = types} = req),
    do: types |> Enum.map(&Validate.tx_type!(&1)) |> MapSet.new()

  def tx_types(%{} = req),
    do: MapSet.new()

  defp expand_tx_group(group),
    do: AeMdw.Node.tx_group(Validate.tx_group!(group))
end

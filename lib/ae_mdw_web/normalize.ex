defmodule AeMdwWeb.Normalize do
  alias AeMdw.Node, as: AE
  alias AeMdw.Validate
  alias AeMdw.Error.Input, as: ErrInput

  import AeMdw.Util

  ##########

  def normalize(combination, {types, ids, fields}),
    do:
      normalize(
        combination,
        {MapSet.size(types), types},
        {MapSet.size(ids), ids},
        {map_size(fields), fields}
      )

  def normalize(_, {0, _}, {0, _}, {0, _}), do: :history

  def normalize(:and, {n, _types}, _, _) when n > 1, do: input_err(:multiple_types)

  def normalize(:or, {0, _}, {0, _}, {_, fields}),
    do: {:object_check_fields_any, fields_roots(fields), fields}

  def normalize(:and, {0, _}, {0, _}, {_, fields}) do
    {_, checks} =
      Enum.reduce(fields, {nil, Map.new()}, fn
        {{type, field, id}, pos}, {one_type, acc} when is_nil(one_type) or one_type == type ->
          {type, Map.update(acc, field, {pos, id}, fn _ -> input_err(:multiple_values) end)}

        {{_type, _field, _id}, _}, {_, _} ->
          input_err(:multiple_types)
      end)

    [{{type, _field, id}, _}] = Enum.take(fields, 1)
    {:object_check_fields_all, MapSet.new([{type, id}]), checks}
  end

  def normalize(:or, {_, types}, {0, _}, {0, _}), do: {:type, types}

  def normalize(:and, {1, types}, {0, _}, {0, _}), do: {:type, types}

  def normalize(:or, {0, _}, {_, ids}, {0, _}),
    do: {:object, AeMdw.Node.tx_types(), ids}

  def normalize(:and, {0, _}, {_, ids}, {0, _}),
    do:
      {:object_check_ids_all, MapSet.new(product(AeMdw.Node.tx_types(), ids)),
       {MapSet.size(ids), ids}}

  def normalize(:or, {_, types}, {_, ids}, {0, _}), do: {:object, types, ids}

  def normalize(:and, {1, types}, {_, ids}, {0, _}),
    do: {:object_check_ids_all, MapSet.new(product(types, ids)), {MapSet.size(ids), ids}}

  def normalize(_, _, _, _), do: input_err(:mixing)

  def fields_roots(fields),
    do:
      Enum.reduce(fields, MapSet.new(), fn {{type, _, id}, _}, acc ->
        MapSet.put(acc, {type, id})
      end)

  def input_err(reason),
    do: raise(AeMdw.Error.Input.Query, value: error_msg(reason))

  defp error_msg(:mixing),
    do: "can not mix explicit types, ids and fields in one query"

  defp error_msg(:multiple_types),
    do: "transaction can't have multiple types"

  defp error_msg(:multiple_values),
    do: "transaction can't have multiple values in one field"

  defp error_msg(:unexpected_parameters),
    do: "endpoint doesn't support query parameters"
end

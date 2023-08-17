defmodule AeMdw.Migrations.AddDupFieldsCounters do
  @moduledoc """
  Indexes pubkey field counters to incorporate duplicate fields counters.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Node
  alias AeMdw.Util

  require Model

  @min_int Util.min_int()
  @max_slots 10

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    ranges =
      1..@max_slots
      |> Enum.map(fn i ->
        {i, <<div(2 ** 256, @max_slots) * (i - 1)::256>>,
         <<div(2 ** 256, @max_slots) * i - 1::256>>}
      end)

    count =
      Node.tx_types()
      |> Enum.flat_map(fn tx_type -> Enum.map(ranges, &{tx_type, &1}) end)
      |> Task.async_stream(
        fn {tx_type, {i, range_start, range_end}} ->
          fields_pos =
            tx_type
            |> Node.tx_ids()
            |> Enum.map(fn {_field, pos} -> pos end)

          duplicated_fields_pos =
            state
            |> duplicated_fields_pos(tx_type, fields_pos, range_start, range_end)
            |> Enum.reduce(%{}, fn key, acc ->
              Map.update(acc, key, 1, &(&1 + 1))
            end)

          IO.puts("DONE WITH #{tx_type} SLOT #{i}/#{@max_slots}")

          duplicated_fields_pos
        end,
        timeout: :infinity,
        ordered: false
      )
      |> Stream.flat_map(fn {:ok, dup_fields_map} -> dup_fields_map end)
      |> Stream.map(fn {{tx_type, pos, pk}, dup_count} ->
        WriteMutation.new(
          Model.IdCount,
          Model.id_count(index: {tx_type, pos, pk}, count: dup_count)
        )
      end)
      |> Stream.chunk_every(1_000)
      |> Stream.each(&State.commit(state, &1))
      |> Enum.count()

    {:ok, count}
  end

  defp duplicated_fields_pos(_state, _tx_type, [_pos], _range_start, _range_end), do: []

  defp duplicated_fields_pos(state, tx_type, [pos | rest_pos], range_start, range_end) do
    state
    |> Collection.stream(Model.Field, {tx_type, pos, range_start, @min_int})
    |> Stream.take_while(&match?({^tx_type, ^pos, pk, _txi} when pk <= range_end, &1))
    |> Stream.flat_map(fn {^tx_type, ^pos, pk, txi} ->
      rest_pos
      |> Enum.filter(fn other_pos ->
        State.exists?(state, Model.Field, {tx_type, other_pos, pk, txi})
      end)
      |> Enum.flat_map(fn other_pos ->
        [
          {tx_type, pos, pk},
          {tx_type, other_pos, pk}
        ]
      end)
    end)
    |> Stream.concat(duplicated_fields_pos(state, tx_type, rest_pos, range_start, range_end))
  end
end

defmodule AeMdw.Migrations.RestructurePreviousNames do
  @moduledoc """
  Index aexn contracts by creation.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Util
  alias AeMdw.Log

  require Model
  require Record
  require Logger

  @partitions Enum.map(0..255, fn char ->
                {<<char>>, <<char, Util.max_256bit_bin()::binary>>}
              end)

  Record.defrecord(:name,
    index: nil,
    active: nil,
    expire: nil,
    revoke: nil,
    auction_timeout: 0,
    owner: nil,
    previous: nil
  )

  defp transform_name(
         name(
           index: plain_name,
           active: active,
           expire: expire,
           revoke: revoke,
           auction_timeout: auction_timeout,
           owner: owner
         )
       ) do
    Model.name(
      index: plain_name,
      active: active,
      expire: expire,
      revoke: revoke,
      auction_timeout: auction_timeout,
      owner: owner
    )
  end

  @spec run(State.t(), boolean()) :: {:async, Enumerable.t()}
  def run(state, _from_start?) do
    tasks =
      [
        Model.ActiveName,
        Model.InactiveName
      ]
      |> Enum.flat_map(fn table ->
        Enum.map(@partitions, fn partition -> {table, partition} end)
      end)
      |> Enum.map(fn {table, partition} ->
        fn -> restructure_names(state, table, partition) end
      end)

    {:async, tasks}
  end

  defp restructure_names(state, table, {start_name, end_name}) do
    count =
      state
      |> Collection.stream(table, start_name)
      |> Stream.take_while(&(&1 < end_name))
      |> Stream.map(&{State.fetch!(state, table, &1), table})
      |> Stream.map(fn
        {Model.name(), _table} ->
          []

        {name(previous: previous) = name, table} ->
          previous_mutations =
            previous
            |> Stream.unfold(fn
              nil ->
                nil

              name(index: plain_name, active: active, previous: previous) = name ->
                prev_name =
                  Model.previous_name(
                    name: transform_name(name),
                    index: {plain_name, active}
                  )

                {prev_name, previous}
            end)
            |> Enum.map(&WriteMutation.new(Model.PreviousName, &1))

          [WriteMutation.new(table, transform_name(name)) | previous_mutations]
      end)
      |> Stream.chunk_every(1_000)
      |> Stream.map(fn mutations ->
        _new_state = State.commit(state, mutations)

        length(mutations)
      end)
      |> Enum.sum()

    Log.info("DONE PROCESSING #{inspect(table)} #{inspect(start_name)} (COUNT #{count})")
  end
end

defmodule AeMdw.Migrations.RestructurePreviousNames do
  @moduledoc """
  Index aexn contracts by creation.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model
  require Record

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
      |> Enum.map(fn table -> fn -> restructure_names(state, table) end end)

    {:async, tasks}
  end

  defp restructure_names(state, table) do
    state
    |> Collection.stream(table, nil)
    |> Stream.map(fn plain_name ->
      {State.fetch!(state, table, plain_name), table}
    end)
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
                  transform_name(name),
                  index: {plain_name, active}
                )

              {prev_name, previous}
          end)
          |> Enum.map(&WriteMutation.new(Model.PreviousName, &1))

        [WriteMutation.new(table, transform_name(name)) | previous_mutations]
    end)
    |> Stream.chunk_every(1_000)
    |> Stream.map(fn mutations ->
      fn -> State.commit(state, mutations) end
    end)
    |> Stream.run()
  end
end

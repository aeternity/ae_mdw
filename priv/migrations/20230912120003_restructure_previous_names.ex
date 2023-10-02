defmodule AeMdw.Migrations.RestructurePreviousNames do
  # credo:disable-for-this-file
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

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    count =
      [
        Model.ActiveName,
        Model.InactiveName
      ]
      |> Enum.map(fn table ->
        state
        |> Collection.stream(table, nil)
        |> Stream.map(&{&1, table})
      end)
      |> Collection.merge(:forward)
      |> Stream.map(fn {plain_name, table} -> State.fetch!(state, table, plain_name) end)
      |> Stream.map(fn
        Model.name() ->
          []

        name(previous: previous) ->
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
      end)
      |> Stream.chunk_every(1_000)
      |> Stream.map(fn mutations ->
        _new_state = State.commit(state, mutations)

        length(mutations)
      end)
      |> Enum.sum()

    {:ok, count}
  end
end

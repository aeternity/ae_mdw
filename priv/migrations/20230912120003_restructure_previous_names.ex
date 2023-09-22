defmodule AeMdw.Migrations.RestructurePreviousNames do
  # credo:disable-for-this-file
  @moduledoc """
  Index aexn contracts by creation.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Sync.AsyncTasks.MigrateWork.Migration

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
    {count, state} =
      <<0>>
      |> Stream.unfold(fn
        nil ->
          nil

        plain_name ->
          first_char = String.at(plain_name, 0) <> <<255>>

          next_plain_names =
            [Model.ActiveName, Model.InactiveName]
            |> Enum.map(fn table ->
              case State.next(state, table, first_char) do
                {:ok, val} -> val
                :none -> nil
              end
            end)
            |> Enum.reject(&is_nil/1)

          case next_plain_names do
            [] ->
              {{plain_name, <<255>>}, nil}

            _names ->
              next_plain_name = Enum.min(next_plain_names)
              {{plain_name, next_plain_name}, next_plain_name}
          end
      end)
      |> Enum.to_list()
      |> IO.inspect(limit: :infinity)
      |> Enum.reduce({0, state}, fn {min_plain_name, max_plain_name}, {count, state} ->
        migration = %Migration{
          mutations_mfa: {__MODULE__, :restructure_names, [min_plain_name, max_plain_name]}
        }

        state = State.enqueue(state, :migrate, [migration])

        {count + 1, state}
      end)

    _state = State.commit(state, [])

    {:ok, count}
  end

  def restructure_names(min_plain_name, max_plain_name) do
    state = State.new()

    [
      Model.ActiveName,
      Model.InactiveName
    ]
    |> Enum.map(fn table ->
      state
      |> Collection.stream(table, min_plain_name)
      |> Stream.map(&{&1, table})
    end)
    |> Collection.merge(:forward)
    |> Stream.take_while(fn {plain_name, _table} -> plain_name < max_plain_name end)
    |> Stream.map(fn {plain_name, table} -> {State.fetch!(state, table, plain_name), table} end)
    |> Stream.filter(&match?({name(), _table}, &1))
    |> Stream.flat_map(fn {name(previous: previous) = name, table} ->
      previous_names_mutations =
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

      [
        WriteMutation.new(table, transform_name(name)) | previous_names_mutations
      ]
    end)
    |> Enum.to_list()
  end
end

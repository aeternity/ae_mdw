defmodule AeMdw.Migrations.IndexPreviousNamesClaimsCount do
  @moduledoc """
  Index previous names with new structure.
  """
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  import Record, only: [defrecord: 2]

  require Model

  defrecord :name,
    index: nil,
    active: nil,
    expire: nil,
    revoke: nil,
    auction_timeout: 0,
    owner: nil

  @dialyzer {:nowarn_function, run: 2}

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    state
    |> Collection.stream(Model.PreviousName, nil)
    |> Stream.map(&State.fetch!(state, Model.PreviousName, &1))
    |> Stream.filter(&match?(Model.previous_name(name: name()), &1))
    |> Stream.map(fn Model.previous_name(
                       index: index,
                       name:
                         name(
                           index: plain_name,
                           active: active,
                           expire: expire,
                           revoke: revoke,
                           auction_timeout: auction_timeout,
                           owner: owner
                         )
                     ) ->
      state
      |> Collection.stream(Model.NameClaim, {plain_name, active, -1})
      |> Stream.take_while(&match?({^plain_name, ^active, _txi_idx}, &1))
      |> Enum.count()
      |> then(
        &Model.previous_name(
          index: index,
          name:
            Model.name(
              index: plain_name,
              active: active,
              expire: expire,
              revoke: revoke,
              auction_timeout: auction_timeout,
              owner: owner,
              claims_count: &1
            )
        )
      )
      |> then(&WriteMutation.new(Model.PreviousName, &1))
    end)
    |> Stream.chunk_every(1_000)
    |> Stream.map(fn mutations ->
      _state = State.commit_db(state, mutations)
      length(mutations)
    end)
    |> Enum.sum()
    |> then(&{:ok, &1})
  end
end

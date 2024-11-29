defmodule AeMdw.Migrations.PopulateRevValidators do
  @moduledoc false
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Collection
  alias AeMdw.Db.State
  alias AeMdw.Db.Model

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    state
    |> Collection.stream(Model.Validator, nil)
    |> Stream.map(fn {pubkey, epoch} ->
      WriteMutation.new(Model.RevValidator, Model.rev_validator(index: {epoch, pubkey}))
    end)
    |> Stream.chunk_every(100)
    |> Stream.map(fn mutations ->
      _state = State.commit(state, mutations)
      length(mutations)
    end)
    |> Enum.sum()
    |> then(&{:ok, &1})
  end
end

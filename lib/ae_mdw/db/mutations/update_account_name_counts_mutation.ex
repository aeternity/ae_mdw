defmodule AeMdw.Db.UpdateAccountNameCountsMutation do
  @moduledoc """
  Updates the account names count table.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model

  @derive AeMdw.Db.Mutation
  defstruct []

  @opaque t() :: %__MODULE__{}

  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(_mutation, state) do
    mutations =
      state
      |> Collection.stream(Model.ActiveNameOwner, :forward, nil, nil)
      |> Enum.reduce(%{}, fn
        {owner, _name}, acc ->
          if Map.has_key?(acc, owner) do
            Map.update!(acc, owner, &(&1 + 1))
          else
            Map.put(acc, owner, 1)
          end
      end)
      |> Enum.map(fn {owner, count} ->
        WriteMutation.new(
          Model.AccountNamesCount,
          Model.account_names_count(index: owner, count: count)
        )
      end)

    State.commit(state, mutations)
  end
end

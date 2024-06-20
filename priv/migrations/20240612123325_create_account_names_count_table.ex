defmodule AeMdw.Migrations.CreateAccountNamesCountTable do
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
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

    updated_count = Enum.count(mutations)

    {:ok, updated_count}
  end
end

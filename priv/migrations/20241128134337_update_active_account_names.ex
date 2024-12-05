defmodule AeMdw.Migrations.UpdateActiveAccountNames do
  @moduledoc """
    Updates the account names count table.
  """
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    mutations =
      Model.ActiveNameOwner
      |> RocksDbCF.stream()
      |> Enum.reduce(%{}, fn
        Model.owner(index: {owner, _}), acc -> Map.update(acc, owner, 1, &(&1 + 1))
      end)
      |> Enum.map(fn {owner, count} ->
        WriteMutation.new(
          Model.AccountNamesCount,
          Model.account_names_count(index: owner, count: count)
        )
      end)

    _state = State.commit(state, mutations)

    updated_count = Enum.count(mutations)

    {:ok, updated_count}
  end
end

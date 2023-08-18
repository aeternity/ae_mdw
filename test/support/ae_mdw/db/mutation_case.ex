defmodule AeMdw.Db.MutationCase do
  @moduledoc """
  Test case setup providing an empty memory store.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias AeMdw.TestSamples, as: TS
      alias AeMdw.Db.Model
      alias AeMdw.Db.State
      alias AeMdw.Db.Store

      import AeMdw.TestUtil

      defp assert_same(state1, state2) do
        Model.column_families()
        |> Enum.all?(fn table ->
          all_keys(state1, table) == all_keys(state2, table)
        end)
      end
    end
  end

  setup tags do
    alias AeMdw.Db.MemStore
    alias AeMdw.Db.NullStore

    if Map.get(tags, :integration, false) or Map.get(tags, :skip_store, false) do
      :ok
    else
      {:ok, store: MemStore.new(NullStore.new())}
    end
  end
end

defmodule AeMdw.Db.MutationCase do
  @moduledoc """
  Test case setup providing an empty memory store.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import AeMdw.TestUtil
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

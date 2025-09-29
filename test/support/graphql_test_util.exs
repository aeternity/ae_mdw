defmodule AeMdwWeb.GraphQL.TestUtil do
  @moduledoc false
  alias AeMdw.Db.State

  @doc """Return current in-memory state or an empty map if unavailable."""
  def state do
    case State.mem_state() do
      %State{} = st -> st
      _ -> %{}
    end
  end
end

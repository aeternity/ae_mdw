defmodule AeMdw.Db.NodeStub do
  @moduledoc """
  This is a stub needed only to satisify a Node plugin requirement (expected hooks/callbacks).

  It doesn't create any database table anymore as the Mdw now manages its own database.
  """

  @spec create_tables() :: []
  def create_tables(), do: []

  @spec create_tables(list()) :: []
  def create_tables(_list), do: []

  @spec check_tables(list()) :: []
  def check_tables(_list), do: []
end

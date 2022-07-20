defmodule AeMdwWeb.TestUtil do
  @moduledoc """
  Test helper funcitons imported by default on all tests.
  """

  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Db.State
  alias Plug.Conn

  @spec handle_input((() -> Conn.t())) :: Conn.t() | String.t()
  def handle_input(f) do
    try do
      f.()
    rescue
      err in [ErrInput] ->
        err.message
    end
  end

  @spec with_store(Conn.t(), Store.t()) :: Conn.t()
  def with_store(conn, store) do
    Conn.assign(conn, :state, State.new(store))
  end
end

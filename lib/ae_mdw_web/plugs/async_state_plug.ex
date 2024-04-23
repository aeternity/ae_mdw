defmodule AeMdwWeb.Plugs.AsyncStatePlug do
  @moduledoc """
  Grabs the latest state and includes it on the assigns map.
  """

  alias Plug.Conn
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.State

  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @spec call(Conn.t(), Plug.opts()) :: Conn.t()
  def call(%Conn{assigns: %{async_state: _state}} = conn, _opts), do: conn

  def call(conn, _opts), do: Conn.assign(conn, :async_state, State.new(AsyncStore.instance()))
end

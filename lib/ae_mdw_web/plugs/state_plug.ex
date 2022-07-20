defmodule AeMdwWeb.Plugs.StatePlug do
  @moduledoc """
  Grabs the latest state and includes it on the assigns map.
  """

  alias Plug.Conn
  alias AeMdw.Db.State

  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @spec call(Conn.t(), Plug.opts()) :: Conn.t()
  def call(%Conn{assigns: %{state: _state}} = conn, _opts), do: conn

  def call(conn, _opts), do: Conn.assign(conn, :state, State.mem_state())
end

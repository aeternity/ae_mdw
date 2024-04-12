defmodule AeMdwWeb.WealthController do
  use AeMdwWeb, :controller

  alias AeMdw.Wealth
  alias Plug.Conn
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.State

  @spec wealth(Conn.t(), map()) :: Conn.t()
  def wealth(
        %Conn{assigns: %{async_state: %State{store: %AsyncStore{} = async_store}}} = conn,
        _params
      ) do
    format_json(conn, Wealth.fetch_balances(async_store))
  end
end

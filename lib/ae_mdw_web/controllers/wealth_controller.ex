defmodule AeMdwWeb.WealthController do
  use AeMdwWeb, :controller

  alias AeMdw.Wealth
  alias Plug.Conn

  @spec wealth(Conn.t(), map()) :: Conn.t()
  def wealth(%Conn{} = conn, _params) do
    format_json(conn, Wealth.fetch_balances())
  end
end

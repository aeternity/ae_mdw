defmodule AeMdwWeb.HyperchainController do
  use AeMdwWeb, :controller

  alias AeMdw.Hyperchain
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Util, as: WebUtil
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias Plug.Conn

  plug PaginatedPlug, order_by: ~w(expiration activation deactivation name)a
  action_fallback(FallbackController)

  @spec leaders(Conn.t(), map()) :: Conn.t()
  def leaders(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} =
      assigns

    state
    |> Hyperchain.fetch_leaders(pagination, scope, cursor)
    |> then(&WebUtil.render(conn, &1))
  end
end

defmodule AeMdwWeb.HyperchainController do
  alias AeMdw.Validate
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

  @spec leader_by_height(Conn.t(), map()) :: Conn.t()
  def leader_by_height(%Conn{assigns: %{state: state}} = conn, %{"height" => height}) do
    with {:ok, height} <- Validate.nonneg_int(height),
         {:ok, leader} <- Hyperchain.fetch_leader_by_height(state, height) do
      format_json(conn, leader)
    end
  end
end

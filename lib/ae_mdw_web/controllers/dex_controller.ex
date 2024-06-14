defmodule AeMdwWeb.DexController do
  @moduledoc """
  DEX endpoints.
  """
  use AeMdwWeb, :controller

  alias AeMdw.Dex
  alias AeMdw.Db.Model
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  require Model

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  @spec swaps(Conn.t(), map()) :: Conn.t()
  def swaps(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, paginated_swaps} <- Dex.fetch_swaps(state, pagination, cursor) do
      Util.render(conn, paginated_swaps)
    end
  end

  @spec account_swaps(Conn.t(), map()) :: Conn.t()
  def account_swaps(%Conn{assigns: assigns} = conn, %{"account_id" => account_id}) do
    %{state: state, pagination: pagination, cursor: cursor, query: query} = assigns

    with {:ok, paginated_swaps} <-
           Dex.fetch_account_swaps(state, account_id, pagination, cursor, query) do
      Util.render(conn, paginated_swaps)
    end
  end

  @spec contract_swaps(Conn.t(), map()) :: Conn.t()
  def contract_swaps(%Conn{assigns: assigns} = conn, %{"contract_id" => contract_id}) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, paginated_swaps} <-
           Dex.fetch_contract_swaps(state, contract_id, pagination, cursor) do
      Util.render(conn, paginated_swaps)
    end
  end
end

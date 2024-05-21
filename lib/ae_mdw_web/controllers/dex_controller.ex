defmodule AeMdwWeb.DexController do
  @moduledoc """
  DEX endpoints.
  """
  use AeMdwWeb, :controller

  import AeMdwWeb.AexnView, only: [render_swap: 2]

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
  def swaps(%Conn{assigns: assigns} = conn, %{
        "caller" => account_id,
        "from_symbol" => token_symbol
      }) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, swaps} <-
           Dex.fetch_swaps_for_account(state, {account_id, token_symbol}, pagination, cursor) do
      Util.render(conn, swaps, &render_swap(state, &1))
    end
  end

  def swaps(%Conn{assigns: assigns} = conn, %{"caller" => account_id}) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, swaps} <- Dex.fetch_swaps_for_account(state, account_id, pagination, cursor) do
      Util.render(conn, swaps, &render_swap(state, &1))
    end
  end

  def swaps(%Conn{assigns: assigns} = conn, %{"from_symbol" => token_symbol}) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, swaps} <- Dex.fetch_swaps_by_token_symbol(state, token_symbol, pagination, cursor) do
      Util.render(conn, swaps, &render_swap(state, &1))
    end
  end

  def swaps(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, swaps} <- Dex.fetch_swaps(state, nil, pagination, cursor) do
      Util.render(conn, swaps, &render_swap(state, &1))
    end
  end

  @spec swaps_for_contract(Conn.t(), map()) :: Conn.t()
  def swaps_for_contract(%Conn{assigns: assigns} = conn, %{"contract_id" => contract_id}) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, swaps} <- Dex.fetch_swaps_by_contract_id(state, contract_id, pagination, cursor) do
      Util.render(conn, swaps, &render_swap(state, &1))
    end
  end
end

defmodule AeMdwWeb.DexController do
  @moduledoc """
  DEX endpoints.
  """
  use AeMdwWeb, :controller

  import AeMdwWeb.AexnView, only: [render_swap: 2]

  alias AeMdw.Dex
  alias AeMdw.Db.Model
  alias AeMdw.Validate
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

    with {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]),
         {:ok, create_txi} <- Dex.validate_token(token_symbol),
         {:ok, swaps} <-
           Dex.fetch_account_swaps(state, {account_pk, create_txi}, pagination, cursor) do
      Util.render(conn, swaps, &render_swap(state, &1))
    end
  end

  def swaps(%Conn{assigns: assigns} = conn, %{"caller" => account_id}) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]),
         {:ok, swaps} <- Dex.fetch_account_swaps(state, account_pk, pagination, cursor) do
      Util.render(conn, swaps, &render_swap(state, &1))
    end
  end

  def swaps(%Conn{assigns: assigns} = conn, %{"from_symbol" => token_symbol}) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, create_txi} <- Dex.validate_token(token_symbol),
         {:ok, swaps} <- Dex.fetch_contract_swaps(state, create_txi, pagination, cursor) do
      Util.render(conn, swaps, &render_swap(state, &1))
    end
  end

  @spec swaps_for_contract(Conn.t(), map()) :: Conn.t()
  def swaps_for_contract(%Conn{assigns: assigns} = conn, %{"contract_id" => contract_id}) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, create_txi} <- Dex.validate_contract_pk(contract_pk, state, contract_id),
         {:ok, swaps} <- Dex.fetch_contract_swaps(state, create_txi, pagination, cursor) do
      Util.render(conn, swaps, &render_swap(state, &1))
    end
  end
end

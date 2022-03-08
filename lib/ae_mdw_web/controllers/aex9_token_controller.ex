defmodule AeMdwWeb.Aex9TokenController do
  alias AeMdw.Aex9
  alias AeMdw.Validate
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  use AeMdwWeb, :controller

  plug PaginatedPlug,
       [order_by: ~w(name symbol)a]
       when action in ~w(aex9_tokens aex9_token_balances aex9_token_balance_history aex9_account_balances)a

  action_fallback(FallbackController)

  @spec aex9_tokens(Conn.t(), map()) :: Conn.t()
  def aex9_tokens(%Conn{assigns: assigns, query_params: query_params} = conn, _params) do
    %{
      pagination: pagination,
      cursor: cursor,
      order_by: order_by
    } = assigns

    case Aex9.fetch_tokens(pagination, query_params, order_by, cursor) do
      {:ok, prev_cursor, aex9_tokens, next_cursor} ->
        Util.paginate(conn, prev_cursor, aex9_tokens, next_cursor)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec aex9_token(Conn.t(), map()) :: Conn.t()
  def aex9_token(conn, %{"contract_id" => contract_id}) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, token} <- Aex9.fetch_token(contract_pk) do
      json(conn, token)
    end
  end

  @spec aex9_token_balances(Conn.t(), map()) :: Conn.t()
  def aex9_token_balances(%Conn{assigns: assigns} = conn, %{"contract_id" => contract_id}) do
    %{
      cursor: cursor,
      pagination: pagination
    } = assigns

    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, prev_cursor, balances, next_cursor} <-
           Aex9.fetch_balances(contract_pk, pagination, cursor) do
      Util.paginate(conn, prev_cursor, balances, next_cursor)
    end
  end

  @spec aex9_token_balance(Conn.t(), map()) :: Conn.t()
  def aex9_token_balance(conn, %{"contract_id" => contract_id, "account_id" => account_id}) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]),
         {:ok, balance} <- Aex9.fetch_balance(contract_pk, account_pk) do
      json(conn, balance)
    end
  end

  @spec aex9_account_balances(Conn.t(), map()) :: Conn.t()
  def aex9_account_balances(%Conn{assigns: assigns} = conn, %{"account_id" => account_id}) do
    %{pagination: pagination, cursor: cursor} = assigns

    with {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]),
         {:ok, prev_cursor, account_balances, next_cursor} <-
           Aex9.fetch_account_balances(account_pk, cursor, pagination) do
      Util.paginate(conn, prev_cursor, account_balances, next_cursor)
    end
  end

  @spec aex9_token_balance_history(Conn.t(), map()) :: Conn.t()
  def aex9_token_balance_history(%Conn{assigns: assigns} = conn, %{
        "contract_id" => contract_id,
        "account_id" => account_id
      }) do
    %{pagination: pagination, cursor: cursor, scope: scope} = assigns

    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]),
         {:ok, prev_cursor, balance_history_items, next_cursor} <-
           Aex9.fetch_balance_history(contract_pk, account_pk, scope, cursor, pagination) do
      Util.paginate(conn, prev_cursor, balance_history_items, next_cursor)
    end
  end
end

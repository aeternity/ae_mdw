defmodule AeMdwWeb.AexnTokenController do
  @moduledoc false

  alias AeMdw.Aex9
  alias AeMdw.AexnTokens
  alias AeMdw.Validate
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  import AeMdwWeb.AexnView

  use AeMdwWeb, :controller

  plug PaginatedPlug, order_by: ~w(name symbol)a

  action_fallback(FallbackController)

  @spec aex9_contracts(Conn.t(), map()) :: Conn.t()
  def aex9_contracts(%Conn{assigns: assigns, query_params: query_params} = conn, _params) do
    aexn_contracts(conn, assigns, query_params, :aex9)
  end

  @spec aex141_contracts(Conn.t(), map()) :: Conn.t()
  def aex141_contracts(%Conn{assigns: assigns, query_params: query_params} = conn, _params) do
    aexn_contracts(conn, assigns, query_params, :aex141)
  end

  @spec aex9_contract(Conn.t(), map()) :: Conn.t()
  def aex9_contract(conn, %{"contract_id" => contract_id}) do
    aexn_contract(conn, contract_id, :aex9)
  end

  @spec aex141_contract(Conn.t(), map()) :: Conn.t()
  def aex141_contract(conn, %{"contract_id" => contract_id}) do
    aexn_contract(conn, contract_id, :aex141)
  end

  @spec aex9_token_balances(Conn.t(), map()) :: Conn.t()
  def aex9_token_balances(%Conn{assigns: assigns} = conn, %{"contract_id" => contract_id}) do
    %{
      cursor: cursor,
      pagination: pagination
    } = assigns

    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, prev_cursor, balances, next_cursor} <-
           Aex9.fetch_chain_balances(contract_pk, pagination, cursor) do
      Util.paginate(conn, prev_cursor, balances, next_cursor)
    end
  end

  @spec aex9_token_balance(Conn.t(), map()) :: Conn.t()
  def aex9_token_balance(%Conn{assigns: %{state: state}} = conn, %{
        "contract_id" => contract_id,
        "account_id" => account_id
      }) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]),
         {:ok, balance} <- Aex9.fetch_balance(state, contract_pk, account_pk) do
      json(conn, balance)
    end
  end

  @spec aex9_account_balances(Conn.t(), map()) :: Conn.t()
  def aex9_account_balances(%Conn{assigns: assigns} = conn, %{"account_id" => account_id}) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]),
         {:ok, prev_cursor, account_balances, next_cursor} <-
           Aex9.fetch_account_balances(state, account_pk, cursor, pagination) do
      Util.paginate(conn, prev_cursor, account_balances, next_cursor)
    end
  end

  @spec aex9_token_balance_history(Conn.t(), map()) :: Conn.t()
  def aex9_token_balance_history(%Conn{assigns: assigns} = conn, %{
        "contract_id" => contract_id,
        "account_id" => account_id
      }) do
    %{pagination: pagination, cursor: cursor, scope: scope, state: state} = assigns

    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]),
         {:ok, prev_cursor, balance_history_items, next_cursor} <-
           Aex9.fetch_balance_history(state, contract_pk, account_pk, scope, cursor, pagination) do
      Util.paginate(conn, prev_cursor, balance_history_items, next_cursor)
    end
  end

  defp aexn_contracts(
         %Conn{assigns: %{state: state}} = conn,
         %{
           pagination: pagination,
           cursor: cursor,
           order_by: order_by
         },
         query_params,
         aexn_type
       ) do
    case AexnTokens.fetch_contracts(state, pagination, aexn_type, query_params, order_by, cursor) do
      {:ok, prev_cursor, aexn_tokens, next_cursor} ->
        Util.paginate(conn, prev_cursor, render_tokens(aexn_tokens), next_cursor)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp aexn_contract(%Conn{assigns: %{state: state}} = conn, contract_id, aexn_type) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, m_aexn} <- AexnTokens.fetch_contract(state, {aexn_type, contract_pk}) do
      json(conn, render_token(m_aexn))
    end
  end
end

defmodule AeMdwWeb.AexnTokenController do
  @moduledoc false

  alias AeMdw.Aex9
  alias AeMdw.AexnTokens
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Validate
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  import AeMdwWeb.AexnView
  import AeMdwWeb.Helpers.AexnHelper, only: [validate_aex9: 1]

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

  @spec aex9_event_balances(Conn.t(), map()) :: Conn.t()
  def aex9_event_balances(%Conn{assigns: assigns} = conn, %{"contract_id" => contract_id}) do
    %{
      state: state,
      cursor: cursor,
      pagination: pagination
    } = assigns

    with {:ok, contract_pk} <- validate_aex9(contract_id),
         {:ok, prev_cursor, balance_keys, next_cursor} <-
           Aex9.fetch_event_balances(state, contract_pk, pagination, cursor) do
      balances = Enum.map(balance_keys, &render_event_balance(state, &1))

      Util.paginate(conn, prev_cursor, balances, next_cursor)
    end
  end

  @spec aex9_token_balance(Conn.t(), map()) :: Conn.t()
  def aex9_token_balance(
        conn,
        %{
          "contract_id" => contract_id,
          "account_id" => account_id
        } = query_params
      ) do
    with {:ok, contract_pk} <- validate_aex9(contract_id),
         {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]),
         {:ok, height_hash} <- validate_block_hash(Map.get(query_params, "hash")),
         {:ok, balance} <- Aex9.fetch_balance(contract_pk, account_pk, height_hash) do
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

    with {:ok, contract_pk} <- validate_aex9(contract_id),
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
    with {:ok, prev_cursor, aexn_contracts, next_cursor} <-
           AexnTokens.fetch_contracts(
             state,
             pagination,
             aexn_type,
             query_params,
             order_by,
             cursor
           ) do
      Util.paginate(conn, prev_cursor, render_contracts(state, aexn_contracts), next_cursor)
    end
  end

  defp aexn_contract(%Conn{assigns: %{state: state}} = conn, contract_id, aexn_type) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, m_aexn} <- AexnTokens.fetch_contract(state, {aexn_type, contract_pk}) do
      json(conn, render_contract(state, m_aexn))
    end
  end

  defp validate_block_hash(nil), do: {:ok, nil}

  defp validate_block_hash(block_id) do
    case :aeser_api_encoder.safe_decode(:block_hash, block_id) do
      {:ok, block_hash} ->
        case :aec_chain.get_block(block_hash) do
          {:ok, block} ->
            {:ok, {:aec_blocks.type(block), :aec_blocks.height(block), block_hash}}

          :error ->
            {:error, ErrInput.NotFound.exception(value: block_id)}
        end

      _any_error ->
        {:error, ErrInput.Query.exception(value: block_id)}
    end
  end
end

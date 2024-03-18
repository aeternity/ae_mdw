defmodule AeMdwWeb.AexnTokenController do
  @moduledoc false

  alias AeMdw.Aex9
  alias AeMdw.AexnTokens
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Validate
  alias AeMdw.Stats
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  import AeMdwWeb.AexnView
  import AeMdwWeb.Helpers.AexnHelper, only: [validate_aex9: 1]

  use AeMdwWeb, :controller

  require Model

  @endpoint_timeout Application.compile_env(:ae_mdw, :endpoint_timeout)

  plug PaginatedPlug,
       [order_by: ~w(name symbol creation)a] when action in ~w(aex9_contracts aex141_contracts)a

  plug PaginatedPlug, [order_by: ~w(pubkey amount)a] when action in ~w(aex9_event_balances)a
  plug PaginatedPlug when action in ~w(aex9_account_balances aex9_token_balance_history)a

  action_fallback(FallbackController)

  @spec aex9_count(Conn.t(), map()) :: Conn.t()
  def aex9_count(%Conn{assigns: %{state: state}} = conn, _params) do
    format_json(conn, %{data: aexn_count(state, :aex9)})
  end

  @spec aex9_logs_count(Conn.t(), map()) :: Conn.t()
  def aex9_logs_count(%Conn{assigns: %{state: state}} = conn, %{"contract_id" => contract_id}) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]) do
      format_json(conn, %{data: Stats.fetch_aex9_logs_count(state, contract_pk)})
    end
  end

  @spec aex9_contracts(Conn.t(), map()) :: Conn.t()
  def aex9_contracts(%Conn{assigns: assigns} = conn, _params) do
    aexn_contracts(conn, assigns, :aex9)
  end

  @spec aex141_count(Conn.t(), map()) :: Conn.t()
  def aex141_count(%Conn{assigns: %{state: state}} = conn, _params) do
    format_json(conn, %{data: aexn_count(state, :aex141)})
  end

  @spec aex141_contracts(Conn.t(), map()) :: Conn.t()
  def aex141_contracts(%Conn{assigns: assigns} = conn, _params) do
    aexn_contracts(conn, assigns, :aex141)
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
      pagination: pagination,
      order_by: order_by,
      query: query
    } = assigns

    with {:ok, paginated_balances} <-
           Aex9.fetch_event_balances(state, contract_id, pagination, cursor, order_by, query) do
      Util.render(conn, paginated_balances)
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
      format_json(conn, balance)
    end
  end

  @spec aex9_account_balances(Conn.t(), map()) :: Conn.t()
  def aex9_account_balances(%Conn{assigns: assigns} = conn, %{"account_id" => account_id}) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, account_pk} <- Validate.id(account_id, [:account_pubkey]) do
      fn -> Aex9.fetch_account_balances(state, account_pk, cursor, pagination) end
      |> Task.async()
      |> Task.yield(@endpoint_timeout)
      |> case do
        {:ok, {:ok, {prev_cursor, account_balances, next_cursor}}} ->
          Util.render(conn, {prev_cursor, account_balances, next_cursor})

        nil ->
          conn
          |> put_status(503)
          |> format_json(%{error: :timeout})
      end
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
         {:ok, {prev_cursor, balance_history_items, next_cursor}} <-
           Aex9.fetch_balance_history(state, contract_pk, account_pk, scope, cursor, pagination) do
      Util.render(conn, {prev_cursor, balance_history_items, next_cursor})
    end
  end

  defp aexn_count(state, aexn_type) do
    Model.stat(payload: count) = State.fetch!(state, Model.Stat, Stats.aexn_count_key(aexn_type))
    count
  end

  defp aexn_contracts(
         %Conn{assigns: %{state: state}} = conn,
         %{
           pagination: pagination,
           cursor: cursor,
           order_by: order_by,
           query: query
         },
         aexn_type
       ) do
    with {:ok, paginated_contracts} <-
           AexnTokens.fetch_contracts(
             state,
             pagination,
             aexn_type,
             query,
             order_by,
             cursor
           ) do
      Util.render(conn, paginated_contracts, &render_contract(state, &1))
    end
  end

  defp aexn_contract(%Conn{assigns: %{state: state}} = conn, contract_id, aexn_type) do
    with {:ok, contract_pk} <- Validate.id(contract_id, [:contract_pubkey]),
         {:ok, m_aexn} <- AexnTokens.fetch_contract(state, {aexn_type, contract_pk}) do
      format_json(conn, render_contract(state, m_aexn))
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

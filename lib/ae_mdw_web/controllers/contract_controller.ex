defmodule AeMdwWeb.ContractController do
  use AeMdwWeb, :controller

  alias AeMdw.Contracts
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  @spec contracts(Conn.t(), map()) :: Conn.t()
  def contracts(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} = assigns

    with {:ok, contracts} <-
           Contracts.fetch_contracts(state, pagination, scope, cursor) do
      Util.render(conn, contracts)
    end
  end

  @spec contract(Conn.t(), map()) :: Conn.t()
  def contract(%Conn{assigns: %{state: state}} = conn, %{"id" => contract_id}) do
    with {:ok, contract} <- Contracts.fetch_contract(state, contract_id) do
      format_json(conn, contract)
    end
  end

  @spec logs(Conn.t(), map()) :: Conn.t()
  def logs(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope, query: query} = assigns

    with {:ok, paginated_logs} <-
           Contracts.fetch_logs(state, pagination, scope, query, cursor, v3?: true) do
      Util.render(conn, paginated_logs)
    end
  end

  @spec logs_v2(Conn.t(), map()) :: Conn.t()
  def logs_v2(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope, query: query} = assigns

    with {:ok, paginated_logs} <-
           Contracts.fetch_logs(state, pagination, scope, query, cursor, v3?: false) do
      Util.render(conn, paginated_logs)
    end
  end

  @spec calls(Conn.t(), map()) :: Conn.t()
  def calls(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope, query: query} = assigns

    with {:ok, paginated_calls} <-
           Contracts.fetch_calls(state, pagination, scope, query, cursor, v3?: true) do
      Util.render(conn, paginated_calls)
    end
  end

  @spec calls_v2(Conn.t(), map()) :: Conn.t()
  def calls_v2(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope, query: query} = assigns

    with {:ok, paginated_calls} <-
           Contracts.fetch_calls(state, pagination, scope, query, cursor, v3?: false) do
      Util.render(conn, paginated_calls)
    end
  end

  @spec contract_logs(Conn.t(), map()) :: Conn.t()
  def contract_logs(%Conn{assigns: assigns} = conn, %{"contract_id" => contract_id}) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope, query: query} = assigns

    with {:ok, paginated_logs} <-
           Contracts.fetch_contract_logs(state, contract_id, pagination, scope, query, cursor) do
      Util.render(conn, paginated_logs)
    end
  end

  @spec contract_calls(Conn.t(), map()) :: Conn.t()
  def contract_calls(%Conn{assigns: assigns} = conn, %{"contract_id" => contract_id}) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope, query: query} = assigns

    with {:ok, paginated_calls} <-
           Contracts.fetch_contract_calls(state, contract_id, pagination, scope, query, cursor) do
      Util.render(conn, paginated_calls)
    end
  end
end

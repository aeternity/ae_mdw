defmodule AeMdwWeb.ContractController do
  use AeMdwWeb, :controller

  alias AeMdw.Contracts
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.LogsView
  alias AeMdwWeb.CallsView
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
    v3? = true

    with {:ok, encode_args} <- valid_args_params(query),
         {:ok, {prev_cursor, logs, next_cursor}} <-
           Contracts.fetch_logs(state, pagination, scope, query, cursor) do
      logs = Enum.map(logs, &LogsView.render_log(state, &1, encode_args, v3?))

      Util.render(conn, prev_cursor, logs, next_cursor)
    end
  end

  @spec logs_v2(Conn.t(), map()) :: Conn.t()
  def logs_v2(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope, query: query} = assigns
    v3? = false

    with {:ok, encode_args} <- valid_args_params(query),
         {:ok, {prev_cursor, logs, next_cursor}} <-
           Contracts.fetch_logs(state, pagination, scope, query, cursor) do
      logs = Enum.map(logs, &LogsView.render_log(state, &1, encode_args, v3?))

      Util.render(conn, prev_cursor, logs, next_cursor)
    end
  end

  @spec calls(Conn.t(), map()) :: Conn.t()
  def calls(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope, query: query} = assigns
    v3? = true

    with {:ok, {prev_cursor, calls, next_cursor}} <-
           Contracts.fetch_calls(state, pagination, scope, query, cursor) do
      calls = Enum.map(calls, &CallsView.render_call(&1, v3?))
      Util.render(conn, prev_cursor, calls, next_cursor)
    end
  end

  @spec calls_v2(Conn.t(), map()) :: Conn.t()
  def calls_v2(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope, query: query} = assigns
    v3? = false

    with {:ok, {prev_cursor, calls, next_cursor}} <-
           Contracts.fetch_calls(state, pagination, scope, query, cursor) do
      calls = Enum.map(calls, &CallsView.render_call(&1, v3?))
      Util.render(conn, prev_cursor, calls, next_cursor)
    end
  end

  defp valid_args_params(query_params) do
    aexn_args = Map.get(query_params, "aexn-args", "false")
    default_custom_args = :persistent_term.get({AeMdwWeb.LogsView, :custom_events_args}, false)
    custom_args = Map.get(query_params, "custom-args", to_string(default_custom_args))

    if aexn_args in ["true", "false"] and custom_args in ["true", "false"] do
      encode_args = %{
        aexn_args: String.to_existing_atom(aexn_args),
        custom_args: String.to_existing_atom(custom_args)
      }

      {:ok, encode_args}
    else
      {:error,
       ErrInput.Query.exception(value: "aexn-args and custom-args should be true or false")}
    end
  end
end

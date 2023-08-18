defmodule AeMdwWeb.ContractController do
  use AeMdwWeb, :controller

  alias AeMdw.Contracts
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.LogsView
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  @spec contracts(Conn.t(), map()) :: Conn.t()
  def contracts(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} = assigns

    with {:ok, {prev_cursor, contracts, next_cursor}} <-
           Contracts.fetch_contracts(state, pagination, scope, cursor) do
      Util.paginate(conn, prev_cursor, contracts, next_cursor)
    end
  end

  @spec contract(Conn.t(), map()) :: Conn.t()
  def contract(%Conn{assigns: %{state: state}} = conn, %{"id" => contract_id}) do
    with {:ok, contract} <- Contracts.fetch_contract(state, contract_id) do
      json(conn, contract)
    end
  end

  @spec logs(Conn.t(), map()) :: Conn.t()
  def logs(%Conn{assigns: assigns, query_params: query_params} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} = assigns

    case valid_args_params(query_params) do
      {:ok, encode_args} ->
        {prev_cursor, logs, next_cursor} =
          Contracts.fetch_logs(state, pagination, scope, query_params, cursor)

        logs = Enum.map(logs, &LogsView.render_log(state, &1, encode_args))

        Util.paginate(conn, prev_cursor, logs, next_cursor)

      {:error, :invalid_args_params} ->
        {:error,
         ErrInput.Query.exception(value: "aexn-args and custom-args should be true or false")}
    end
  end

  @spec calls(Conn.t(), map()) :: Conn.t()
  def calls(%Conn{assigns: assigns, query_params: query_params} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} = assigns

    calls = Contracts.fetch_calls(state, pagination, scope, query_params, cursor)
    Util.paginate(conn, calls)
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
      {:error, :invalid_args_params}
    end
  end
end

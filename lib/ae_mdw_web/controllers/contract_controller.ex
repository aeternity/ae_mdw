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

    with {:ok, encode_args} <- valid_args_params(query_params),
         {:ok, prev_cursor, logs, next_cursor} <-
           Contracts.fetch_logs(state, pagination, scope, query_params, cursor) do
      logs = Enum.map(logs, &LogsView.render_log(state, &1, encode_args))

      Util.paginate(conn, prev_cursor, logs, next_cursor)
    else
      {:error, :invalid_args_params} ->
        {:error,
         ErrInput.Query.exception(value: "aexn-args and custom-args should be true or false")}

      {:error, reason} ->
        Util.send_error(conn, :bad_request, reason)
    end
  end

  @spec calls(Conn.t(), map()) :: Conn.t()
  def calls(%Conn{assigns: assigns, query_params: query_params} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} = assigns

    state
    |> Contracts.fetch_calls(pagination, scope, query_params, cursor)
    |> then(fn {:ok, calls} -> Util.paginate(conn, calls) end)
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

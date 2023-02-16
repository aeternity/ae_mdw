defmodule AeMdwWeb.ContractController do
  use AeMdwWeb, :controller

  alias AeMdw.Contracts
  alias AeMdwWeb.AexnLogView
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  plug(PaginatedPlug)

  @spec logs(Conn.t(), map()) :: Conn.t()
  def logs(%Conn{assigns: assigns, query_params: query_params} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} = assigns
    encode_args? = Map.get(query_params, "aexn-args", "false")

    with true <- encode_args? in ["true", "false"],
         {:ok, prev_cursor, logs, next_cursor} <-
           Contracts.fetch_logs(state, pagination, scope, query_params, cursor) do
      encode_args? = String.to_existing_atom(encode_args?)
      logs = Enum.map(logs, &AexnLogView.render_log(state, &1, encode_args?))

      Util.paginate(conn, prev_cursor, logs, next_cursor)
    else
      false ->
        {:error, ErrInput.Query.exception(value: "aexn-args should be true or false")}

      {:error, reason} ->
        Util.send_error(conn, :bad_request, reason)
    end
  end

  @spec calls(Conn.t(), map()) :: Conn.t()
  def calls(%Conn{assigns: assigns, query_params: query_params} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} = assigns

    case Contracts.fetch_calls(state, pagination, scope, query_params, cursor) do
      {:ok, prev_cursor, calls, next_cursor} ->
        Util.paginate(conn, prev_cursor, calls, next_cursor)

      {:error, reason} ->
        Util.send_error(conn, :bad_request, reason)
    end
  end
end

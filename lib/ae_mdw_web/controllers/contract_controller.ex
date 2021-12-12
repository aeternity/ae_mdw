defmodule AeMdwWeb.ContractController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  alias AeMdw.Contracts
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias Plug.Conn

  import AeMdwWeb.Util

  plug(PaginatedPlug)

  @spec logs(Conn.t(), map()) :: Conn.t()
  def logs(
        %Conn{assigns: assigns, request_path: path, query_params: query_params} = conn,
        _params
      ) do
    %{direction: direction, limit: limit, cursor: cursor, scope: scope} = assigns

    case Contracts.fetch_logs(direction, scope, query_params, cursor, limit) do
      {:ok, logs, new_cursor} ->
        uri =
          if new_cursor do
            next_params = Map.merge(query_params, %{"cursor" => new_cursor, "limit" => limit})

            URI.to_string(%URI{path: path, query: URI.encode_query(next_params)})
          end

        json(conn, %{"data" => logs, "next" => uri})

      {:error, reason} ->
        send_error(conn, :bad_request, reason)
    end
  end

  @spec calls(Conn.t(), map()) :: Conn.t()
  def calls(
        %Conn{assigns: assigns, request_path: path, query_params: query_params} = conn,
        _params
      ) do
    %{direction: direction, limit: limit, cursor: cursor, scope: scope} = assigns

    case Contracts.fetch_calls(direction, scope, query_params, cursor, limit) do
      {:ok, calls, new_cursor} ->
        uri =
          if new_cursor do
            next_params = Map.merge(query_params, %{"cursor" => new_cursor, "limit" => limit})

            URI.to_string(%URI{path: path, query: URI.encode_query(next_params)})
          end

        json(conn, %{"data" => calls, "next" => uri})

      {:error, reason} ->
        send_error(conn, :bad_request, reason)
    end
  end
end

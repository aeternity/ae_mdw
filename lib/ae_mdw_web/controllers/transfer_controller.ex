defmodule AeMdwWeb.TransferController do
  use AeMdwWeb, :controller
  use PhoenixSwagger

  alias AeMdw.Transfers
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias Plug.Conn

  import AeMdwWeb.Util

  plug(PaginatedPlug)

  @spec transfers(Conn.t(), map()) :: Conn.t()
  def transfers(
        %Conn{assigns: assigns, query_params: query_params, request_path: path} = conn,
        _params
      ) do
    %{direction: direction, limit: limit, cursor: cursor, scope: scope} = assigns

    case Transfers.fetch_transfers(direction, scope, query_params, cursor, limit) do
      {:ok, transfers, next_cursor} ->
        uri =
          if next_cursor do
            next_params = Map.merge(query_params, %{"cursor" => next_cursor, "limit" => limit})

            URI.to_string(%URI{path: path, query: URI.encode_query(next_params)})
          end

        json(conn, %{"data" => transfers, "next" => uri})

      {:error, reason} ->
        send_error(conn, :bad_request, reason)
    end
  end
end

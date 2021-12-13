defmodule AeMdwWeb.StatsController do
  use AeMdwWeb, :controller

  alias AeMdw.Stats
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias Plug.Conn

  plug(PaginatedPlug)

  @spec stats(Conn.t(), map()) :: Conn.t()
  def stats(%Conn{assigns: assigns, request_path: path} = conn, _params) do
    %{direction: direction, limit: limit, cursor: cursor, scope: scope} = assigns

    {stats, next_cursor} = Stats.fetch_stats(direction, scope, cursor, limit)

    uri =
      if next_cursor do
        %URI{
          path: path,
          query: URI.encode_query(%{"cursor" => next_cursor, "limit" => limit})
        }
        |> URI.to_string()
      end

    json(conn, %{"data" => stats, "next" => uri})
  end

  @spec sum_stats(Conn.t(), map()) :: Conn.t()
  def sum_stats(%Conn{assigns: assigns, request_path: path} = conn, _params) do
    %{direction: direction, limit: limit, cursor: cursor, scope: scope} = assigns

    {stats, next_cursor} = Stats.fetch_sum_stats(direction, scope, cursor, limit)

    uri =
      if next_cursor do
        %URI{
          path: path,
          query: URI.encode_query(%{"cursor" => next_cursor, "limit" => limit})
        }
        |> URI.to_string()
      end

    json(conn, %{"data" => stats, "next" => uri})
  end
end

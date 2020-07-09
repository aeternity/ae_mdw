defmodule AeMdwWeb.Util do
  alias AeMdw.Db.Model
  alias AeMdw.Error.Input, as: ErrInput

  require Model

  import AeMdw.Util

  ##########

  def query_groups(query_string) do
    query_string
    |> URI.query_decoder()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  def expand_query_group({key, vals}) do
    vals
    |> Enum.map(&URI.encode_query(%{key => &1}))
    |> Enum.join("&")
  end

  def url_encode_scope({scope, %Range{first: a, last: b}}),
    do: "#{scope}/#{a}-#{b}"

  def make_link(path_info, scope, query_groups) do
    path =
      List.last(path_info)
      |> case do
        dir when dir in ["forward", "backward"] ->
          :lists.droplast(path_info) ++ [url_encode_scope(scope)]

        _ ->
          path_info
      end
      |> Enum.join("/")

    query =
      query_groups
      |> Enum.map(&expand_query_group/1)
      |> Enum.join("&")

    case query do
      "" -> path
      _ -> path <> "?" <> query
    end
  end

  def next_link(path_info, scope, query_groups, limit, page) do
    next_offset = %{"limit" => [to_string(limit)], "page" => [to_string(page + 1)]}
    make_link(path_info, scope, Map.merge(query_groups, next_offset))
  end

  def handle_input(conn, f) do
    try do
      f.()
    rescue
      err in [ErrInput] ->
        conn |> send_error(:bad_request, err.message)
    end
  end

  def send_error(conn, status, reason) do
    conn
    |> Plug.Conn.put_status(status)
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Phoenix.Controller.json(%{"error" => reason})
  end

  def user_agent(%Plug.Conn{req_headers: headers}) do
    case headers |> Enum.find(&(elem(&1, 0) == "user-agent")) do
      {_, val} -> val
      nil -> nil
    end
  end

  def concat(prefix, val),
    do: prefix <> ": " <> ((is_binary(val) && String.printable?(val) && val) || inspect(val))
end

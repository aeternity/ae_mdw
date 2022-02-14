defmodule AeMdwWeb.Util do
  @moduledoc """
  Web-specific utils module.
  """

  alias AeMdw.Collection
  alias AeMdw.Error.Input, as: ErrInput
  alias Phoenix.Controller
  alias Plug.Conn

  # credo:disable-for-next-line
  def expand?(query_params), do: presence?(query_params, "expand")

  # credo:disable-for-next-line
  def presence?(%Plug.Conn{query_params: query_params}, name),
    do: presence?(query_params, name)

  # credo:disable-for-next-line
  def presence?(%{} = query_params, name) do
    case Map.get(query_params, name, :not_found) do
      x when x in [nil, "true", [nil], ["true"], "", [""]] -> true
      _val -> false
    end
  end

  # credo:disable-for-next-line
  def query_groups(query_string) do
    query_string
    |> URI.query_decoder()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> case do
      %{"expand" => [nil]} = groups ->
        Map.put(groups, "expand", ["true"])

      groups ->
        groups
    end
  end

  # credo:disable-for-next-line
  def expand_query_group({key, vals}) do
    vals
    |> Enum.map(&URI.encode_query(%{key => &1}))
    |> Enum.join("&")
  end

  defp url_encode_scope({scope, %Range{first: a, last: b}}),
    do: "#{scope}/#{a}-#{b}"

  defp path_no_scope([_ | _] = path_info),
    do:
      Enum.take_while(
        path_info,
        &(!(&1 in ["gen", "txi", "time", "forward", "backward"] || String.contains?(&1, "-")))
      )

  defp make_link(path_info, scope, query_groups) do
    path_info = path_no_scope(path_info)
    scope_info = (scope == nil && []) || [url_encode_scope(scope)]
    path = "/" <> Enum.join(path_info ++ scope_info, "/")

    query =
      query_groups
      |> Enum.map(&expand_query_group/1)
      |> Enum.join("&")

    case query do
      "" -> path
      _query -> path <> "?" <> query
    end
  end

  # credo:disable-for-next-line
  def next_link(path_info, scope, query_groups, limit, page) do
    next_offset = %{"limit" => [to_string(limit)], "page" => [to_string(page + 1)]}
    make_link(path_info, scope, Map.merge(query_groups, next_offset))
  end

  # credo:disable-for-next-line
  def handle_input(conn, f) do
    try do
      f.()
    rescue
      err in [ErrInput] ->
        conn |> send_error(err.reason, err.message)
    end
  end

  # credo:disable-for-next-line
  def send_error(conn, reason, message) do
    status = error_reason_to_status(reason)

    conn
    |> Plug.Conn.put_status(status)
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Phoenix.Controller.json(%{"error" => message})
  end

  defp error_reason_to_status(ErrInput.NotFound), do: :not_found
  defp error_reason_to_status(_err), do: :bad_request

  # credo:disable-for-next-line
  def user_agent(%Plug.Conn{req_headers: headers}) do
    case headers |> Enum.find(&(elem(&1, 0) == "user-agent")) do
      {_, val} -> val
      nil -> nil
    end
  end

  # credo:disable-for-next-line
  def concat(prefix, val),
    do: prefix <> ": " <> ((is_binary(val) && String.printable?(val) && val) || inspect(val))

  # credo:disable-for-next-line
  def prefix_checker(prefix) do
    prefix_size = :erlang.size(prefix)

    fn data ->
      is_binary(data) &&
        :erlang.size(data) >= prefix_size &&
        :binary.part(data, {0, prefix_size}) == prefix
    end
  end

  @spec paginate(
          Conn.t(),
          Collection.pagination_cursor(),
          Enumerable.t(),
          Collection.pagination_cursor()
        ) :: Conn.t()
  def paginate(
        %Conn{request_path: path, query_params: query_params} = conn,
        prev_cursor,
        data,
        next_cursor
      ) do
    prev_uri = encode_cursor(path, query_params, prev_cursor)
    next_uri = encode_cursor(path, query_params, next_cursor)

    Controller.json(conn, %{"data" => data, "next" => next_uri, "prev" => prev_uri})
  end

  defp encode_cursor(_path, _query_params, nil), do: nil

  defp encode_cursor(path, query_params, {cursor, is_reversed?}) do
    query_params =
      if is_reversed? do
        Map.put(query_params, "rev", "1")
      else
        Map.delete(query_params, "rev")
      end

    query_params = Map.put(query_params, "cursor", cursor)

    %URI{path: path, query: URI.encode_query(query_params)} |> URI.to_string()
  end
end

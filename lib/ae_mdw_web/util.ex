defmodule AeMdwWeb.Util do
  alias AeMdw.Db.Model
  alias AeMdw.Error.Input, as: ErrInput

  require Model

  ##########

  # def expand?(%{"expand" => x}) when x in [nil, "true", [nil], ["true"]], do: true
  # def expand?(%{}), do: false

  def expand?(query_params), do: presence?(query_params, "expand")

  def presence?(%Plug.Conn{query_params: query_params}, name),
    do: presence?(query_params, name)

  def presence?(%{} = query_params, name) do
    case Map.get(query_params, name, :not_found) do
      x when x in [nil, "true", [nil], ["true"], "", [""]] -> true
      _ -> false
    end
  end

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

  def expand_query_group({key, vals}) do
    vals
    |> Enum.map(&URI.encode_query(%{key => &1}))
    |> Enum.join("&")
  end

  def url_encode_scope({scope, %Range{first: a, last: b}}),
    do: "#{scope}/#{a}-#{b}"

  def path_no_scope([_ | _] = path_info),
    do:
      Enum.take_while(
        path_info,
        &(!(&1 in ["gen", "txi", "time", "forward", "backward"] || String.contains?(&1, "-")))
      )

  def make_link(path_info, scope, query_groups) do
    path_info = path_no_scope(path_info)
    scope_info = (scope == nil && []) || [url_encode_scope(scope)]
    path = "/" <> Enum.join(path_info ++ scope_info, "/")

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
        conn |> send_error(err.reason, err.message)
    end
  end

  def send_error(conn, reason, message) do
    status = error_reason_to_status(reason)

    conn
    |> Plug.Conn.put_status(status)
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Phoenix.Controller.json(%{"error" => message})
  end

  defp error_reason_to_status(ErrInput.NotFound), do: :not_found
  defp error_reason_to_status(_), do: :bad_request

  def user_agent(%Plug.Conn{req_headers: headers}) do
    case headers |> Enum.find(&(elem(&1, 0) == "user-agent")) do
      {_, val} -> val
      nil -> nil
    end
  end

  def concat(prefix, val),
    do: prefix <> ": " <> ((is_binary(val) && String.printable?(val) && val) || inspect(val))

  def prefix_checker(prefix) do
    prefix_size = :erlang.size(prefix)

    fn data ->
      is_binary(data) &&
        :erlang.size(data) >= prefix_size &&
        :binary.part(data, {0, prefix_size}) == prefix
    end
  end
end

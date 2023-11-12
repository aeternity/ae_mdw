defmodule AeMdwWeb.Util do
  @moduledoc """
  Web-specific utils module.
  """

  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Validate
  alias AeMdw.Error.Input, as: ErrInput
  alias Phoenix.Controller
  alias Plug.Conn

  @type render_json_fn :: (Database.key() -> map()) | (Database.record() -> map())

  @spec parse_range(binary()) :: {:ok, Range.t()} | {:error, binary}
  def parse_range(range) do
    case String.split(range, "-") do
      [from, to] ->
        case {Validate.nonneg_int(from), Validate.nonneg_int(to)} do
          {{:ok, from}, {:ok, to}} -> {:ok, from..to}
          {{:ok, _}, {:error, {_, detail}}} -> {:error, detail}
          {{:error, {_, detail}}, _} -> {:error, detail}
        end

      [x] ->
        case Validate.nonneg_int(x) do
          {:ok, x} -> {:ok, x..x}
          {:error, {_, detail}} -> {:error, detail}
        end

      _invalid_range ->
        {:error, range}
    end
  end

  @spec query_groups(binary()) :: map()
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

  @spec handle_input(Conn.t(), (() -> Conn.t())) :: Conn.t()
  def handle_input(conn, f) do
    try do
      f.()
    rescue
      err in [ErrInput] ->
        conn |> send_error(err.reason, err.message)
    end
  end

  @spec send_error(Plug.Conn.t(), ErrInput.reason(), String.t()) :: Plug.Conn.t()
  def send_error(conn, reason, message) do
    status = error_reason_to_status(reason)

    conn
    |> Plug.Conn.put_status(status)
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Phoenix.Controller.json(%{"error" => message})
  end

  defp error_reason_to_status(ErrInput.NotFound), do: :not_found
  defp error_reason_to_status(_err), do: :bad_request

  @spec concat(binary(), term()) :: binary()
  def concat(prefix, val),
    do: prefix <> ": " <> ((is_binary(val) && String.printable?(val) && val) || inspect(val))

  @spec prefix_checker(binary()) :: (binary() -> boolean())
  def prefix_checker(prefix) do
    prefix_size = :erlang.size(prefix)

    fn data ->
      is_binary(data) &&
        :erlang.size(data) >= prefix_size &&
        :binary.part(data, {0, prefix_size}) == prefix
    end
  end

  @spec render(
          Conn.t(),
          Collection.pagination_cursor(),
          Enumerable.t(),
          Collection.pagination_cursor()
        ) :: Conn.t()
  def render(
        %Conn{request_path: path, query_params: query_params} = conn,
        prev_cursor,
        data,
        next_cursor
      ) do
    prev_uri = encode_cursor(path, query_params, prev_cursor)
    next_uri = encode_cursor(path, query_params, next_cursor)

    Controller.json(conn, %{"data" => data, "next" => next_uri, "prev" => prev_uri})
  end

  @spec render(
          Conn.t(),
          {Collection.pagination_cursor(), Enumerable.t(), Collection.pagination_cursor()},
          render_json_fn()
        ) :: Conn.t()
  def render(conn, {prev_cursor, data_list, next_cursor}, render_json_fn) do
    data = Enum.map(data_list, render_json_fn)
    render(conn, prev_cursor, data, next_cursor)
  end

  @spec render(
          Conn.t(),
          {Collection.pagination_cursor(), Enumerable.t(), Collection.pagination_cursor()}
        ) :: Conn.t()
  def render(conn, {prev_cursor, data, next_cursor}),
    do: render(conn, prev_cursor, data, next_cursor)

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

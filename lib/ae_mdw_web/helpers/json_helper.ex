defmodule AeMdwWeb.Helpers.JSONHelper do
  @moduledoc """
  Special helpers to additionally pre-process JSON content.
  """

  alias Plug.Conn

  @spec format_json(Conn.t(), term(), Conn.status()) :: Conn.t()
  def format_json(conn, data, status \\ 200) do
    conn
    |> Conn.put_resp_header("content-type", "application/json")
    |> Conn.resp(status, :jsx.encode(convert_ints_to_string(conn, data)))
    |> Conn.halt()
  end

  defp convert_ints_to_string(%Conn{assigns: %{int_as_string: true}}, val) when is_integer(val),
    do: to_string(val)

  defp convert_ints_to_string(_conn, val) when is_integer(val), do: val

  defp convert_ints_to_string(conn, val) when is_map(val),
    do: Map.new(val, fn {key, val} -> {key, convert_ints_to_string(conn, val)} end)

  defp convert_ints_to_string(conn, val) when is_list(val),
    do: for(i <- val, do: convert_ints_to_string(conn, i))

  defp convert_ints_to_string(_conn, nil), do: :null

  defp convert_ints_to_string(_conn, val), do: val
end

defmodule AeMdwWeb.Helpers.JSONHelper do
  @moduledoc """
  Special helpers to additionally pre-process JSON content.
  """

  alias Phoenix.Controller
  alias Plug.Conn

  @spec format_json(Conn.t(), term()) :: Conn.t()
  def format_json(%Conn{assigns: %{int_as_string: true}} = conn, data),
    do: Controller.json(conn, convert_ints_to_string(data))

  def format_json(conn, data), do: Controller.json(conn, data)

  defp convert_ints_to_string(val) when is_integer(val), do: to_string(val)

  defp convert_ints_to_string(val) when is_map(val),
    do: Map.new(val, fn {key, val} -> {key, convert_ints_to_string(val)} end)

  defp convert_ints_to_string(val) when is_list(val),
    do: for(i <- val, do: convert_ints_to_string(i))

  defp convert_ints_to_string(val), do: val
end

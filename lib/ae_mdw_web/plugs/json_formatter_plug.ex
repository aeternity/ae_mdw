defmodule AeMdwWeb.Plugs.JSONFormatterPlug do
  @moduledoc """
  Plug to mark JSON content formatting options.
  """

  alias Plug.Conn

  @spec init([]) :: []
  def init(opts), do: opts

  @spec call(Conn.t(), map()) :: Conn.t()
  def call(%Conn{query_params: %{"int-as-string" => "true"}} = conn, _opts) do
    conn
    |> Conn.assign(:int_as_string, true)
    |> remove_param("int-as-string")
  end

  def call(conn, _opts), do: conn

  defp remove_param(%Conn{query_params: query_params} = conn, key),
    do: %Conn{conn | query_params: Map.delete(query_params, key)}
end

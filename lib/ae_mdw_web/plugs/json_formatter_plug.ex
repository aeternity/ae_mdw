defmodule AeMdwWeb.Plugs.JSONFormatterPlug do
  @moduledoc """
  Plug to mark JSON content formatting options.
  """

  alias Plug.Conn

  @spec init([]) :: []
  def init(opts), do: opts

  @spec call(Conn.t(), map()) :: Conn.t()
  def call(%Conn{query_params: %{"int-as-string" => "true"}} = conn, _opts) do
    Conn.assign(conn, :int_as_string, true)
  end

  def call(conn, _opts), do: conn
end

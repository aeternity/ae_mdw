defmodule AeMdwWeb.Plugs.HyperchainPlug do
  @moduledoc """
  Prevents action if the controller is not on a hyperchain node.
  """

  alias Plug.Conn
  alias Phoenix.Controller
  alias AeMdw.Hyperchain

  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @spec call(Conn.t(), Plug.opts()) :: Conn.t()
  def call(conn, _opts) do
    if Hyperchain.hyperchain?() do
      conn
    else
      conn
      |> Conn.put_status(:bad_request)
      |> Controller.json(%{"error" => "Not on a hyperchain node"})
      |> Conn.halt()
    end
  end
end

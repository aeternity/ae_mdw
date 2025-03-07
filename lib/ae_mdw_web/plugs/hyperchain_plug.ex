defmodule AeMdwWeb.Plugs.HyperchainPlug do
  @moduledoc """
  Prevents action if the controller is not on a hyperchain node.
  """

  alias Plug.Conn
  alias Phoenix.Controller
  alias AeMdw.Sync.Hyperchain

  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @spec call(Conn.t(), Plug.opts()) :: Conn.t()
  def call(conn, opts) do
    should_allow = Hyperchain.hyperchain?() != (opts[:reverse?] || false)

    if should_allow do
      conn
    else
      message =
        if opts[:reverse?] do
          "This endpoint is not available on a hyperchain node"
        else
          "This endpoint is only available on a hyperchain node"
        end

      conn
      |> Conn.put_status(:bad_request)
      |> Controller.json(%{"error" => message})
      |> Conn.halt()
    end
  end
end


defmodule AeMdwWeb.ChannelController do
  use AeMdwWeb, :controller

  alias AeMdw.Channels
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  @spec channels(Conn.t(), map()) :: Conn.t()
  def channels(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, scope: scope, cursor: cursor} = assigns

    with {:ok, prev_cursor, channels, next_cursor} <-
           Channels.fetch_active_channels(state, pagination, scope, cursor) do
      Util.paginate(conn, prev_cursor, channels, next_cursor)
    end
  end

  @spec channel(Conn.t(), map()) :: Conn.t()
  def channel(%Conn{assigns: %{state: state}} = conn, %{"id" => id}) do
    with {:ok, channel} <- Channels.fetch_channel(state, id) do
      json(conn, channel)
    end
  end
end

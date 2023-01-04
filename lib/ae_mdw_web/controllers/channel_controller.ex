defmodule AeMdwWeb.ChannelController do
  use AeMdwWeb, :controller

  alias AeMdw.Validate
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
  def channel(%Conn{assigns: %{state: state}} = conn, %{"id" => id} = params) do
    block_hash = params["block_hash"]

    with {:ok, channel_pk} <- Validate.id(id, [:channel]),
         true <- valid_optional_block_hash?(block_hash),
         {:ok, channel} <- Channels.fetch_channel(state, channel_pk, block_hash) do
      json(conn, channel)
    end
  end

  defp valid_optional_block_hash?(nil), do: true

  defp valid_optional_block_hash?(block_hash) do
    case Validate.id(block_hash) do
      {:ok, _hash} -> true
      {:error, _reason} -> false
    end
  end
end

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
    %{state: state, pagination: pagination, scope: scope, query: query, cursor: cursor} = assigns

    with {:ok, paginated_channels} <-
           Channels.fetch_channels(state, pagination, scope, query, cursor) do
      Util.render(conn, paginated_channels)
    end
  end

  @spec channel(Conn.t(), map()) :: Conn.t()
  def channel(%Conn{assigns: %{state: state}} = conn, %{"id" => id} = params) do
    block_hash = params["block_hash"]

    with {:ok, channel_pk} <- Validate.id(id, [:channel]),
         {:ok, type_block_hash} <- valid_optional_block_hash?(block_hash),
         {:ok, channel} <- Channels.fetch_channel(state, channel_pk, type_block_hash) do
      json(conn, channel)
    end
  end

  @spec channel_updates(Conn.t(), map()) :: Conn.t()
  def channel_updates(%Conn{assigns: assigns} = conn, %{"id" => id}) do
    %{state: state, pagination: pagination, scope: scope, cursor: cursor} = assigns

    with {:ok, paginated_updates} <-
           Channels.fetch_channel_updates(state, id, pagination, scope, cursor) do
      Util.render(conn, paginated_updates)
    end
  end

  defp valid_optional_block_hash?(nil), do: {:ok, nil}

  defp valid_optional_block_hash?(block_hash) do
    with {:ok, hash} <- Validate.id(block_hash) do
      if String.starts_with?(block_hash, "kh") do
        {:ok, {:key, hash}}
      else
        {:ok, {:micro, hash}}
      end
    end
  end
end

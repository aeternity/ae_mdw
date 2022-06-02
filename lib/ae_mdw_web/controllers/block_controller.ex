defmodule AeMdwWeb.BlockController do
  use AeMdwWeb, :controller

  alias AeMdw.Blocks
  alias AeMdw.Validate
  alias AeMdw.Util
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util, as: WebUtil
  alias Plug.Conn

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  ##########

  @doc """
  Endpoint for block info by hash or kbi.
  """
  @spec block(Conn.t(), map()) :: Conn.t()
  def block(%Conn{assigns: %{state: state}} = conn, %{"hash_or_kbi" => hash_or_kbi} = params) do
    case Util.parse_int(hash_or_kbi) do
      {:ok, _kbi} ->
        blocki(conn, Map.put(params, "kbi", hash_or_kbi))

      :error ->
        with {:ok, block_hash} <- Validate.id(hash_or_kbi),
             {:ok, block} <- Blocks.fetch(state, block_hash) do
          json(conn, block)
        end
    end
  end

  @doc """
  Endpoint for block info by kbi.
  """
  @spec blocki(Conn.t(), map()) :: Conn.t()
  def blocki(%Conn{assigns: %{state: state}} = conn, %{"kbi" => kbi} = params) do
    mbi = Map.get(params, "mbi", "-1")

    with {:ok, block_index} <- Validate.block_index(kbi <> "/" <> mbi),
         {:ok, block} <- Blocks.fetch(state, block_index) do
      json(conn, block)
    end
  end

  @doc """
  Endpoint for blocks info based on pagination.
  """
  @spec blocks_v1(Conn.t(), map()) :: Conn.t()
  def blocks_v1(%Conn{assigns: assigns} = conn, _params) do
    %{
      state: state,
      pagination: {direction, _is_reversed?, limit, _has_cursor?},
      cursor: cursor,
      scope: scope
    } = assigns

    {prev_cursor, blocks, next_cursor} =
      Blocks.fetch_blocks(state, direction, scope, cursor, limit, false)

    WebUtil.paginate(conn, prev_cursor, blocks, next_cursor)
  end

  @doc """
  Endpoint for paginated blocks with sorted micro blocks per time.
  """
  @spec blocks(Conn.t(), map()) :: Conn.t()
  def blocks(%Conn{assigns: assigns} = conn, _params) do
    %{
      state: state,
      pagination: {direction, _is_reversed?, limit, _has_cursor?},
      cursor: cursor,
      scope: scope
    } = assigns

    {prev_cursor, blocks, next_cursor} =
      Blocks.fetch_blocks(state, direction, scope, cursor, limit, true)

    WebUtil.paginate(conn, prev_cursor, blocks, next_cursor)
  end
end

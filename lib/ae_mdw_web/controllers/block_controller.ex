defmodule AeMdwWeb.BlockController do
  use AeMdwWeb, :controller

  alias AeMdw.Blocks
  alias AeMdw.Validate
  alias AeMdw.Util
  alias AeMdw.Error.Input, as: ErrInput
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
  def block(%Conn{assigns: %{state: state}} = conn, %{"hash_or_kbi" => hash_or_kbi}) do
    case Validate.nonneg_int(hash_or_kbi) do
      {:ok, kbi} ->
        case Blocks.fetch_blocks(state, :forward, {:gen, kbi..kbi}, nil, 1, true) do
          {_prev_cursor, [block], _next_cursor} ->
            json(conn, block)

          {nil, [], nil} ->
            {:error, ErrInput.NotFound.exception(value: hash_or_kbi)}
        end

      {:error, _reason} ->
        with {:ok, block} <- Blocks.fetch(state, hash_or_kbi) do
          json(conn, block)
        end
    end
  end

  @doc """
  Endpoint for block info by hash or kbi.
  """
  @spec block_v1(Conn.t(), map()) :: Conn.t()
  def block_v1(%Conn{assigns: %{state: state}} = conn, %{"hash_or_kbi" => hash_or_kbi} = params) do
    case Util.parse_int(hash_or_kbi) do
      {:ok, _kbi} ->
        blocki(conn, Map.put(params, "kbi", hash_or_kbi))

      :error ->
        case Blocks.fetch(state, hash_or_kbi) do
          {:ok, block} -> json(conn, block)
          {:error, reason} -> {:error, reason}
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

  @spec key_blocks(Conn.t(), map()) :: Conn.t()
  def key_blocks(%Conn{assigns: assigns} = conn, _params) do
    %{
      state: state,
      pagination: {direction, _is_reversed?, limit, _has_cursor?},
      cursor: cursor,
      scope: scope
    } = assigns

    {prev_cursor, blocks, next_cursor} =
      Blocks.fetch_key_blocks(state, direction, scope, cursor, limit)

    WebUtil.paginate(conn, prev_cursor, blocks, next_cursor)
  end

  @spec key_block(Conn.t(), map()) :: Conn.t()
  def key_block(%Conn{assigns: %{state: state}} = conn, %{"hash_or_kbi" => hash_or_kbi}) do
    with {:ok, block} <- Blocks.fetch_key_block(state, hash_or_kbi) do
      json(conn, block)
    end
  end

  @spec key_block_micro_blocks(Conn.t(), map()) :: Conn.t()
  def key_block_micro_blocks(%Conn{assigns: assigns} = conn, %{"hash_or_kbi" => hash_or_kbi}) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor
    } = assigns

    with {:ok, paginated_blocks} <-
           Blocks.fetch_key_block_micro_blocks(state, hash_or_kbi, pagination, cursor) do
      WebUtil.paginate(conn, paginated_blocks)
    end
  end

  @spec micro_block(Conn.t(), map()) :: Conn.t()
  def micro_block(%Conn{assigns: %{state: state}} = conn, %{"hash" => hash}) do
    with {:ok, block} <- Blocks.fetch_micro_block(state, hash) do
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

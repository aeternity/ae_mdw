defmodule AeMdwWeb.BlockController do
  use AeMdwWeb, :controller

  alias AeMdw.Blocks
  alias AeMdw.Validate
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  plug(PaginatedPlug, txi_scope?: false)
  action_fallback(FallbackController)

  ##########

  @doc """
  Endpoint for block info by hash or kbi.
  """
  @spec block(Conn.t(), map()) :: Conn.t()
  def block(%Conn{assigns: %{state: state}} = conn, %{"hash_or_kbi" => hash_or_kbi}) do
    case Validate.nonneg_int(hash_or_kbi) do
      {:ok, kbi} ->
        case Blocks.fetch_blocks(state, :forward, {:gen, kbi..kbi}, nil, 1) do
          {:ok, {_prev_cursor, [block], _next_cursor}} ->
            format_json(conn, block)

          {:ok, {_prev_cursor, [], _next_cursor}} ->
            {:error, ErrInput.NotFound.exception(value: hash_or_kbi)}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, _reason} ->
        with {:ok, block} <- Blocks.fetch(state, hash_or_kbi) do
          format_json(conn, block)
        end
    end
  end

  @doc """
  Endpoint for block info by kbi and mbi.
  """
  @spec blocki(Conn.t(), map()) :: Conn.t()
  def blocki(%Conn{assigns: %{state: state}} = conn, %{"kbi" => kbi, "mbi" => mbi}) do
    with {:ok, block_index} <- Validate.block_index(kbi <> "/" <> mbi),
         {:ok, block} <- Blocks.fetch(state, block_index) do
      format_json(conn, block)
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

    with {:ok, paginated_blocks} <-
           Blocks.fetch_key_blocks(state, direction, scope, cursor, limit) do
      Util.render(conn, paginated_blocks)
    end
  end

  @spec key_block(Conn.t(), map()) :: Conn.t()
  def key_block(%Conn{assigns: %{state: state}} = conn, %{"hash_or_kbi" => hash_or_kbi}) do
    with {:ok, block} <- Blocks.fetch_key_block(state, hash_or_kbi) do
      format_json(conn, block)
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
      Util.render(conn, paginated_blocks)
    end
  end

  @spec micro_block(Conn.t(), map()) :: Conn.t()
  def micro_block(%Conn{assigns: %{state: state}} = conn, %{"hash" => hash}) do
    with {:ok, block} <- Blocks.fetch_micro_block(state, hash) do
      format_json(conn, block)
    end
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

    with {:ok, paginated_blocks} <- Blocks.fetch_blocks(state, direction, scope, cursor, limit) do
      Util.render(conn, paginated_blocks)
    end
  end
end

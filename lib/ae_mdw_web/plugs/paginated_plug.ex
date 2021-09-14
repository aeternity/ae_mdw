defmodule AeMdwWeb.Plugs.PaginatedPlug do
  @moduledoc """
  """

  import Plug.Conn

  alias Plug.Conn

  @direction_map %{
    "forward" => :forward,
    "backward" => :backward
  }
  @valid_directions Map.keys(@direction_map)
  @default_direction :backward

  @default_limit 10
  @max_limit 20

  @spec init(Plug.opts()) :: Conn.t()
  def init(opts), do: opts

  @spec call(Conn.t(), Plug.opts()) :: Conn.t()
  def call(%Conn{params: params} = conn, _opts) do
    direction =
      case Map.fetch(params, "direction") do
        {:ok, direction} when direction in @valid_directions -> Map.get(@direction_map, direction)
        {:ok, _direction} -> @default_direction
        :error -> @default_direction
      end

    limit =
      case Integer.parse(Map.get(params, "limit", "")) do
        {limit, ""} when limit <= @max_limit and limit > 0 -> limit
        {_limit, _rest} -> @default_limit
        :error -> @default_limit
      end

    conn
    |> assign(:direction, direction)
    |> assign(:cursor, Map.get(params, "cursor"))
    |> assign(:limit, limit)
  end

  def call(conn, _opts), do: conn
end

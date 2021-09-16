defmodule AeMdwWeb.Plugs.PaginatedPlug do
  @moduledoc """
  """

  import Plug.Conn

  alias Phoenix.Controller
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
    with {:ok, direction} <- extract_direction(params),
         {:ok, limit} <- extract_limit(params) do
      conn
      |> assign(:direction, direction)
      |> assign(:cursor, Map.get(params, "cursor"))
      |> assign(:limit, limit)
      |> assign(:expand?, Map.get(params, "expand", "false") != "false")
    else
      {:error, error_msg} ->
        conn
        |> put_status(:bad_request)
        |> Controller.json(%{"error" => error_msg})
        |> halt()
    end
  end

  def call(conn, _opts), do: conn

  defp extract_direction(params) do
    case Map.fetch(params, "direction") do
      {:ok, direction} when direction in @valid_directions ->
        {:ok, Map.get(@direction_map, direction)}

      {:ok, direction} ->
        {:error, "invalid query: direction=#{direction}"}

      :error ->
        {:ok, @default_direction}
    end
  end

  defp extract_limit(params) do
    limit_bin = Map.get(params, "limit", "#{@default_limit}")

    case Integer.parse(limit_bin) do
      {limit, ""} when limit <= @max_limit and limit > 0 -> {:ok, limit}
      {limit, ""} -> {:error, "limit too large: #{limit}"}
      {_limit, _rest} -> {:error, "invalid limit: #{limit_bin}"}
      :error -> {:error, "invalid limit: #{limit_bin}"}
    end
  end
end

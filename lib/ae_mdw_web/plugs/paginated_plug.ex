defmodule AeMdwWeb.Plugs.PaginatedPlug do
  @moduledoc """
  """

  import Plug.Conn

  alias Phoenix.Controller
  alias Plug.Conn

  @type opts() :: [order_by: [atom()] | Plug.opts()]

  @direction_map %{
    "forward" => :forward,
    "backward" => :backward
  }
  @valid_directions Map.keys(@direction_map)
  @default_direction :backward

  @default_limit 10
  @max_limit 100

  @spec init(opts()) :: opts()
  def init(opts), do: opts

  @spec call(Conn.t(), opts()) :: Conn.t()
  def call(%Conn{params: params} = conn, opts) do
    with {:ok, direction} <- extract_direction(params),
         {:ok, limit} <- extract_limit(params),
         {:ok, order_by} <- extract_order_by(params, opts) do
      conn
      |> assign(:direction, direction)
      |> assign(:cursor, Map.get(params, "cursor"))
      |> assign(:limit, limit)
      |> assign(:expand?, Map.get(params, "expand", "false") != "false")
      |> assign(:order_by, order_by)
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

  defp extract_order_by(params, opts) do
    case {Keyword.get(opts, :order_by), Map.get(params, "by")} do
      {nil, _order_by} ->
        {:ok, nil}

      {[first_order | _rest], nil} ->
        {:ok, first_order}

      {valid_orders, order_by} ->
        case Enum.find(valid_orders, &(Atom.to_string(&1) == order_by)) do
          nil -> {:error, "invalid query: by=#{order_by}"}
          valid_order_by -> {:ok, valid_order_by}
        end
    end
  end
end

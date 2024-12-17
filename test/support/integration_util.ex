defmodule AeMdw.IntegrationUtil do
  @moduledoc """
  Integration tests helper functions.
  """

  import Phoenix.ConnTest
  import ExUnit.Assertions

  @endpoint AeMdwWeb.Endpoint

  defmodule PaginationParams do
    @moduledoc false
    @enforce_keys [:url]
    defstruct [:url, params: [], entries_range: 1..10]
  end

  @spec scan(any(), Conn.t(), any(), (any(), any() -> any())) :: any()
  def scan(%{"next" => nil, "data" => data}, _conn, accumulator, f) do
    f.(data, accumulator)
  end

  def scan(%{"next" => next, "data" => data}, conn, accumulator, f) do
    new_acc = f.(data, accumulator)

    %URI{path: path, query: query} = URI.parse(next)

    conn
    |> get(path <> "?" <> query)
    |> json_response(200)
    |> scan(conn, new_acc, f)
  end

  @spec test_pagination(Conn.t(), PaginationParams.t()) :: any()
  def test_pagination(conn, %PaginationParams{
        url: url,
        params: params,
        entries_range: entries_range
      }) do
    for limit <- entries_range do
      %{"data" => initial_data, "next" => next} =
        conn
        |> get(url, params ++ [{:limit, limit}])
        |> json_response(200)

      %URI{path: path, query: query} = URI.parse(next)

      %{"prev" => prev, "data" => next_data} =
        conn
        |> get(path <> "?" <> query)
        |> json_response(200)

      refute initial_data == next_data

      %URI{path: path, query: query} = URI.parse(prev)

      %{"data" => prev_data} =
        conn
        |> get(path <> "?" <> query)
        |> json_response(200)

      assert initial_data == prev_data
    end
  end
end

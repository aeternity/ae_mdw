defmodule AeMdw.IntegrationUtil do
  @moduledoc """
  Integration tests helper functions.
  """

  import Phoenix.ConnTest

  @endpoint AeMdwWeb.Endpoint

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
end

defmodule AeMdwWeb.DataOffsetPlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(%Plug.Conn{query_params: %{"limit" => limit, "page" => page}} = conn, _opts) do
    case {Integer.parse(limit), Integer.parse(page)} do
      {{limit, ""}, {page, ""}} ->
        conn
        |> assign(:limit_page, {limit, page})

      err_state ->
        {context, value} =
          case err_state do
            {{_, ""}, _} -> {"page", page}
            {_, {_, ""}} -> {"limit", limit}
          end

        conn
        |> send_resp(400, Jason.encode!(%{reason: "invalid #{context}: #{inspect(value)}"}))
        |> halt
    end
  end

  def call(%Plug.Conn{query_params: %{"page" => page}} = conn, opts),
    do: call(%{conn | query_params: put_in(conn.query_params, ["limit"], "10")}, opts)

  def call(conn, _opts), do: conn
end

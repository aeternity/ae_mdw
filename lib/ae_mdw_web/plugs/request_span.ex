defmodule AeMdwWeb.Plugs.RequestSpan do
  @moduledoc """
  Emits telemetry request duration events associating them to a route.
  """

  alias Plug.Conn

  @type opts() :: []

  @spec init(opts()) :: opts()
  def init(opts), do: opts

  @spec call(Conn.t(), opts()) :: Conn.t()
  def call(conn, _opts) do
    conn
    |> Conn.assign(:start_time, System.monotonic_time(:millisecond))
    |> Conn.register_before_send(&emit_event_callback/1)
  end

  @spec emit_event_callback(Conn.t()) :: Conn.t()
  def emit_event_callback(conn) do
    duration = System.monotonic_time(:millisecond) - conn.assigns.start_time

    with %{route: route} <-
           Phoenix.Router.route_info(AeMdwWeb.Router, conn.method, conn.request_path, conn.host),
         [request_id | _ignored] <- Conn.get_resp_header(conn, "x-request-id") do
      metadata = %{route: route, request_id: request_id}
      :telemetry.execute([:ae_mdw, :http, :request], %{duration: duration}, metadata)
      conn
    else
      _error -> conn
    end
  end
end

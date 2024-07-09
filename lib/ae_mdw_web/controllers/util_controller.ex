defmodule AeMdwWeb.UtilController do
  @moduledoc """
  Endpoint for observing Mdw state.
  """
  use AeMdwWeb, :controller

  alias AeMdw.Db.Status
  alias AeMdw.Error.Input
  alias AeMdwWeb.Util
  alias Plug.Conn

  @spec status(Conn.t(), map()) :: Conn.t()
  def status(%Conn{assigns: %{state: state}} = conn, _params),
    do: format_json(conn, Status.node_and_mdw_status(state))

  @spec no_route(Conn.t(), map()) :: Conn.t()
  def no_route(conn, _params),
    do: Util.send_error(conn, Input.NotFound, "no such route")

  @spec static_file(Conn.t(), map()) :: Conn.t()
  def static_file(%Conn{assigns: %{filepath: filepath}} = conn, _params) do
    filepath = Path.join(:code.priv_dir(:ae_mdw), filepath)

    if File.exists?(filepath) do
      send_file(conn, 200, filepath)
    else
      Util.send_error(conn, Input.NotFound, "no such route")
    end
  end

  @spec api(Conn.t(), map()) :: Conn.t()
  def api(conn, _params) do
    filepath = Path.join(:code.priv_dir(:ae_mdw), "static/swagger/swagger_v3.json")

    with true <- File.exists?(filepath),
         {:ok, file} <- File.read(filepath),
         {:ok, api} <- Jason.decode(file) do
      server_url =
        conn
        |> request_url()
        |> URI.parse()
        |> Map.get(:path)
        |> Path.split()
        |> Enum.drop(-1)
        |> Path.join()

      [server] = Map.get(api, "servers")
      api = Map.put(api, "servers", [Map.put(server, "url", server_url)])
      json(conn, api)
    else
      _error ->
        Util.send_error(conn, Input.NotFound, "no such route")
    end
  end
end

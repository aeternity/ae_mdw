defmodule AeMdwWeb.OracleController do
  use AeMdwWeb, :controller

  alias AeMdw.Validate
  alias AeMdw.Oracles
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  plug(PaginatedPlug)
  action_fallback(FallbackController)

  ##########

  @spec oracle(Conn.t(), map()) :: Conn.t()
  def oracle(%Conn{assigns: %{state: state}} = conn, %{"id" => id} = params) do
    with {:ok, oracle_pk} <- Validate.id(id, [:oracle_pubkey]),
         {:ok, oracle} <- Oracles.fetch(state, oracle_pk, Util.expand?(params)) do
      json(conn, oracle)
    end
  end

  @spec inactive_oracles(Conn.t(), map()) :: Conn.t()
  def inactive_oracles(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, expand?: expand?} = assigns

    {prev_cursor, oracles, next_cursor} =
      Oracles.fetch_inactive_oracles(state, pagination, cursor, expand?)

    Util.paginate(conn, prev_cursor, oracles, next_cursor)
  end

  @spec active_oracles(Conn.t(), map()) :: Conn.t()
  def active_oracles(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, expand?: expand?} = assigns

    {prev_cursor, oracles, next_cursor} =
      Oracles.fetch_active_oracles(state, pagination, cursor, expand?)

    Util.paginate(conn, prev_cursor, oracles, next_cursor)
  end

  @spec oracles(Conn.t(), map()) :: Conn.t()
  def oracles(%Conn{assigns: assigns, query_params: query_params} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, expand?: expand?, scope: scope} =
      assigns

    case Oracles.fetch_oracles(state, pagination, scope, query_params, cursor, expand?) do
      {:ok, prev_cursor, oracles, next_cursor} ->
        Util.paginate(conn, prev_cursor, oracles, next_cursor)

      {:error, reason} ->
        {:error, reason}
    end
  end
end

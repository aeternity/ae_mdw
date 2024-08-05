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
  def oracle(%Conn{assigns: %{state: state, opts: opts}} = conn, %{"id" => id}) do
    with opts <- [{:v3?, true} | opts],
         {:ok, oracle_pk} <- Validate.id(id, [:oracle_pubkey]),
         {:ok, oracle} <- Oracles.fetch(state, oracle_pk, opts) do
      format_json(conn, oracle)
    end
  end

  @spec oracle_v2(Conn.t(), map()) :: Conn.t()
  def oracle_v2(%Conn{assigns: %{state: state, opts: opts}} = conn, %{"id" => id}) do
    with {:ok, oracle_pk} <- Validate.id(id, [:oracle_pubkey]),
         {:ok, oracle} <- Oracles.fetch(state, oracle_pk, opts) do
      format_json(conn, oracle)
    end
  end

  @spec inactive_oracles(Conn.t(), map()) :: Conn.t()
  def inactive_oracles(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, opts: opts} = assigns

    paginated_oracles = Oracles.fetch_inactive_oracles(state, pagination, cursor, opts)

    Util.render(conn, paginated_oracles)
  end

  @spec active_oracles(Conn.t(), map()) :: Conn.t()
  def active_oracles(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, opts: opts} = assigns

    paginated_oracles = Oracles.fetch_active_oracles(state, pagination, cursor, opts)

    Util.render(conn, paginated_oracles)
  end

  @spec oracles(Conn.t(), map()) :: Conn.t()
  def oracles(%Conn{assigns: assigns} = conn, _params) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor,
      opts: opts,
      scope: scope,
      query: query
    } = assigns

    opts = [{:v3?, true} | opts]

    with {:ok, paginated_oracles} <-
           Oracles.fetch_oracles(state, pagination, scope, query, cursor, opts) do
      Util.render(conn, paginated_oracles)
    end
  end

  @spec oracles_v2(Conn.t(), map()) :: Conn.t()
  def oracles_v2(%Conn{assigns: assigns} = conn, _params) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor,
      opts: opts,
      scope: scope,
      query: query
    } = assigns

    with {:ok, paginated_oracles} <-
           Oracles.fetch_oracles(state, pagination, scope, query, cursor, opts) do
      Util.render(conn, paginated_oracles)
    end
  end

  @spec oracle_queries(Conn.t(), map()) :: Conn.t()
  def oracle_queries(%Conn{assigns: assigns} = conn, %{"id" => oracle_id}) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} = assigns

    with {:ok, paginated_queries} <-
           Oracles.fetch_oracle_queries(state, oracle_id, pagination, scope, cursor) do
      Util.render(conn, paginated_queries)
    end
  end

  @spec oracle_responses(Conn.t(), map()) :: Conn.t()
  def oracle_responses(%Conn{assigns: assigns} = conn, %{"id" => oracle_id}) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} = assigns

    with {:ok, paginated_responses} <-
           Oracles.fetch_oracle_responses(state, oracle_id, pagination, scope, cursor) do
      Util.render(conn, paginated_responses)
    end
  end

  @spec oracle_extends(Conn.t(), map()) :: Conn.t()
  def oracle_extends(%Conn{assigns: assigns} = conn, %{"id" => oracle_id}) do
    %{state: state, pagination: pagination, cursor: cursor} = assigns

    with {:ok, paginated_extends} <-
           Oracles.fetch_oracle_extends(state, oracle_id, pagination, cursor) do
      Util.render(conn, paginated_extends)
    end
  end
end

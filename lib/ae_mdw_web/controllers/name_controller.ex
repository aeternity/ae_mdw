defmodule AeMdwWeb.NameController do
  use AeMdwWeb, :controller

  alias AeMdw.AuctionBids
  alias AeMdw.Names
  alias AeMdw.Validate
  alias AeMdw.Db.Name
  alias AeMdw.Db.Model
  alias AeMdw.Db.Format
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn
  alias AeMdw.Util
  alias AeMdwWeb.Util, as: WebUtil

  plug PaginatedPlug, order_by: ~w(expiration activation deactivation name)a
  action_fallback(FallbackController)

  @lifecycles_map %{
    "active" => :active,
    "inactive" => :inactive,
    "auction" => :auction
  }
  @lifecycles Map.keys(@lifecycles_map)

  @spec auction_v2(Conn.t(), map()) :: Conn.t()
  def auction_v2(%Conn{assigns: %{state: state, opts: opts}} = conn, %{"id" => ident}) do
    with {:ok, plain_name} <- Validate.plain_name(state, ident) do
      case Name.locate_bid(state, plain_name) do
        nil ->
          {:error, ErrInput.NotFound.exception(value: plain_name)}

        auction_bid ->
          format_json(
            conn,
            Format.to_map(state, auction_bid, Model.AuctionBid, Util.expand?(opts))
          )
      end
    end
  end

  @spec pointees(Conn.t(), map()) :: Conn.t()
  def pointees(%Conn{assigns: assigns} = conn, %{"account_id" => account_id}) do
    %{state: state, pagination: pagination, scope: scope, cursor: cursor} = assigns

    with {:ok, paginated_pointees} <-
           Names.fetch_pointees(state, account_id, pagination, scope, cursor) do
      WebUtil.render(conn, paginated_pointees)
    end
  end

  @spec pointees_v2(Conn.t(), map()) :: Conn.t()
  def pointees_v2(%Conn{assigns: %{state: state}} = conn, %{"id" => ident}) do
    with {:ok, pubkey} <- Validate.name_id(ident) do
      {active, inactive} = Name.pointees(state, pubkey)

      format_json(conn, %{
        "active" => Format.map_raw_values(active, &Format.to_json/1),
        "inactive" => Format.map_raw_values(inactive, &Format.to_json/1)
      })
    end
  end

  @spec name(Conn.t(), map()) :: Conn.t()
  def name(%Conn{assigns: %{state: state, opts: opts}} = conn, %{"id" => ident}) do
    opts = [{:render_v3?, true} | opts]

    with {:ok, name} <- Names.fetch_name(state, ident, opts) do
      format_json(conn, name)
    end
  end

  @spec auction(Conn.t(), map()) :: Conn.t()
  def auction(%Conn{assigns: %{state: state, opts: opts}} = conn, %{"id" => plain_name_or_hash}) do
    opts = [{:render_v3?, true} | opts]

    with {:ok, plain_name} <- Validate.plain_name(state, plain_name_or_hash),
         {:ok, auction_bid} <- AuctionBids.fetch_auction(state, plain_name, opts) do
      format_json(conn, auction_bid)
    end
  end

  @spec name_v2(Conn.t(), map()) :: Conn.t()
  def name_v2(%Conn{assigns: %{state: state, opts: opts}} = conn, %{"id" => ident}) do
    with {:ok, plain_name} <- Validate.plain_name(state, ident),
         {{info, source}, _plain_name} <- {Name.locate(state, plain_name), plain_name} do
      format_json(conn, Format.to_map(state, info, source, Util.expand?(opts)))
    else
      {nil, plain_name} -> {:error, ErrInput.NotFound.exception(value: plain_name)}
    end
  end

  @spec auctions(Conn.t(), map()) :: Conn.t()
  def auctions(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, opts: opts, order_by: order_by} =
      assigns

    with {:ok, paginated_auctions} <-
           AuctionBids.fetch_auctions(state, pagination, order_by, cursor, [
             {:render_v3?, true} | opts
           ]) do
      WebUtil.render(conn, paginated_auctions)
    end
  end

  @spec auctions_v2(Conn.t(), map()) :: Conn.t()
  def auctions_v2(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, opts: opts, order_by: order_by} =
      assigns

    with {:ok, paginated_auctions} <-
           AuctionBids.fetch_auctions(state, pagination, order_by, cursor, opts) do
      WebUtil.render(conn, paginated_auctions)
    end
  end

  @spec auction_claims(Conn.t(), map()) :: Conn.t()
  def auction_claims(%Conn{assigns: assigns} = conn, %{"id" => plain_name_or_hash}) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} = assigns

    with {:ok, plain_name} <- Validate.plain_name(state, plain_name_or_hash),
         {:ok, paginated_bids} <-
           Names.fetch_auction_claims(state, plain_name, pagination, scope, cursor) do
      WebUtil.render(conn, paginated_bids)
    end
  end

  @spec names(Conn.t(), map()) :: Conn.t()
  def names(%Conn{assigns: assigns} = conn, _params) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor,
      opts: opts,
      order_by: order_by,
      scope: scope,
      query: query
    } = assigns

    opts = [{:render_v3?, true} | opts]

    with {:ok, names} <-
           Names.fetch_names(state, pagination, scope, order_by, query, cursor, opts) do
      WebUtil.render(conn, names)
    end
  end

  @spec names_count(Conn.t(), map()) :: Conn.t()
  def names_count(%Conn{assigns: %{state: state, query: query}} = conn, _params) do
    with {:ok, count} <- Names.count_names(state, query) do
      format_json(conn, count)
    end
  end

  @spec names_v2(Conn.t(), map()) :: Conn.t()
  def names_v2(%Conn{assigns: assigns} = conn, _params) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor,
      opts: opts,
      order_by: order_by,
      scope: scope,
      query: query
    } = assigns

    with {:ok, names} <-
           Names.fetch_names(state, pagination, scope, order_by, query, cursor, opts) do
      WebUtil.render(conn, names)
    end
  end

  @spec name_history(Conn.t(), map()) :: Conn.t()
  def name_history(%Conn{assigns: assigns} = conn, %{"id" => name_or_hash}) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor
    } = assigns

    name_or_hash = Validate.ensure_name_suffix(name_or_hash)

    with {:ok, paginated_history} <-
           Names.fetch_name_history(state, pagination, name_or_hash, cursor) do
      WebUtil.render(conn, paginated_history)
    end
  end

  @spec search(Conn.t(), map()) :: Conn.t()
  def search(%Conn{assigns: assigns, query_string: query_string} = conn, params) do
    prefix = Map.get(params, "prefix", "")

    lifecycles =
      query_string
      |> URI.query_decoder()
      |> Enum.filter(&match?({"only", lifecycle} when lifecycle in @lifecycles, &1))
      |> Enum.map(fn {"only", lifecycle} -> Map.fetch!(@lifecycles_map, lifecycle) end)
      |> Enum.uniq()

    %{state: state, pagination: pagination, cursor: cursor, opts: opts} = assigns

    names = Names.search_names(state, lifecycles, prefix, pagination, cursor, opts)

    WebUtil.render(conn, names)
  end

  @spec name_claims(Conn.t(), map()) :: Conn.t()
  def name_claims(%Conn{assigns: assigns} = conn, %{"id" => name_id}) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor,
      scope: scope
    } = assigns

    with {:ok, claims} <- Names.fetch_name_claims(state, name_id, pagination, scope, cursor) do
      WebUtil.render(conn, claims)
    end
  end

  @spec name_transfers(Conn.t(), map()) :: Conn.t()
  def name_transfers(%Conn{assigns: assigns} = conn, %{"id" => name_id}) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor,
      scope: scope
    } = assigns

    with {:ok, transfers} <- Names.fetch_name_transfers(state, name_id, pagination, scope, cursor) do
      WebUtil.render(conn, transfers)
    end
  end

  @spec name_updates(Conn.t(), map()) :: Conn.t()
  def name_updates(%Conn{assigns: assigns} = conn, %{"id" => name_id}) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor,
      scope: scope
    } = assigns

    with {:ok, updates} <- Names.fetch_name_updates(state, name_id, pagination, scope, cursor) do
      WebUtil.render(conn, updates)
    end
  end

  @spec account_claims(Conn.t(), map()) :: Conn.t()
  def account_claims(%Conn{assigns: assigns} = conn, %{"account_id" => account_id}) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} = assigns

    with {:ok, paginated_claims} <-
           Names.fetch_account_claims(state, account_id, pagination, scope, cursor) do
      WebUtil.render(conn, paginated_claims)
    end
  end
end

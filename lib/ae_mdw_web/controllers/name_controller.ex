defmodule AeMdwWeb.NameController do
  use AeMdwWeb, :controller

  alias AeMdw.AuctionBids
  alias AeMdw.Names
  alias AeMdw.Validate
  alias AeMdw.Db.Name
  alias AeMdw.Db.Model
  alias AeMdw.Db.Format
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.FallbackController
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  require Model

  import AeMdwWeb.Util
  import AeMdw.Util

  plug PaginatedPlug, order_by: ~w(expiration activation deactivation name)a
  action_fallback(FallbackController)

  @lifecycles_map %{
    "active" => :active,
    "inactive" => :inactive,
    "auction" => :auction
  }
  @lifecycles Map.keys(@lifecycles_map)

  @spec auction(Conn.t(), map()) :: Conn.t()
  def auction(%Conn{assigns: %{state: state, opts: opts}} = conn, %{"id" => ident}),
    do:
      handle_input(conn, fn ->
        auction_reply(conn, Validate.plain_name!(state, ident), opts)
      end)

  @spec pointers(Conn.t(), map()) :: Conn.t()
  def pointers(%Conn{assigns: %{state: state}} = conn, %{"id" => ident}),
    do: handle_input(conn, fn -> pointers_reply(conn, Validate.plain_name!(state, ident)) end)

  @spec pointees(Conn.t(), map()) :: Conn.t()
  def pointees(conn, %{"id" => ident}),
    do: handle_input(conn, fn -> pointees_reply(conn, Validate.name_id!(ident)) end)

  @spec name(Conn.t(), map()) :: Conn.t()
  def name(%Conn{assigns: %{state: state, opts: opts}} = conn, %{"id" => ident}),
    do:
      handle_input(conn, fn ->
        name_reply(conn, Validate.plain_name!(state, ident), opts)
      end)

  @spec owned_by(Conn.t(), map()) :: Conn.t()
  def owned_by(%Conn{assigns: %{opts: opts}} = conn, %{"id" => owner} = params),
    do:
      handle_input(conn, fn ->
        active? = Map.get(params, "active", "true") == "true"
        owned_by_reply(conn, Validate.id!(owner, [:account_pubkey]), opts, active?)
      end)

  @spec auctions(Conn.t(), map()) :: Conn.t()
  def auctions(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, opts: opts, order_by: order_by} =
      assigns

    paginated_auctions =
      AuctionBids.fetch_auctions(state, pagination, order_by, cursor, [{:render_v3?, true} | opts])

    Util.paginate(conn, paginated_auctions)
  end

  @spec auctions_v2(Conn.t(), map()) :: Conn.t()
  def auctions_v2(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, opts: opts, order_by: order_by} =
      assigns

    paginated_auctions = AuctionBids.fetch_auctions(state, pagination, order_by, cursor, opts)
    Util.paginate(conn, paginated_auctions)
  end

  @spec inactive_names(Conn.t(), map()) :: Conn.t()
  def inactive_names(%Conn{assigns: assigns} = conn, _params) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor,
      opts: opts,
      order_by: order_by,
      scope: scope
    } = assigns

    case Names.fetch_inactive_names(state, pagination, scope, order_by, cursor, opts) do
      {:ok, pagianted_names} -> Util.paginate(conn, pagianted_names)
      {:error, reason} -> Util.send_error(conn, :bad_request, reason)
    end
  end

  @spec active_names(Conn.t(), map()) :: Conn.t()
  def active_names(%Conn{assigns: assigns} = conn, _params) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor,
      opts: opts,
      order_by: order_by,
      scope: scope
    } = assigns

    case Names.fetch_active_names(state, pagination, scope, order_by, cursor, opts) do
      {:ok, paginated_names} -> Util.paginate(conn, paginated_names)
      {:error, reason} -> Util.send_error(conn, :bad_request, reason)
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

    with {:ok, paginated_names} <-
           Names.fetch_names(state, pagination, scope, order_by, query, cursor, [
             {:render_v3?, true} | opts
           ]) do
      Util.paginate(conn, paginated_names)
    end
  end

  @spec names_v2(Conn.t(), map()) :: Conn.t()
  def names_v2(%Conn{assigns: assigns, query_params: query} = conn, _params) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor,
      opts: opts,
      order_by: order_by,
      scope: scope
    } = assigns

    case Names.fetch_names(state, pagination, scope, order_by, query, cursor, opts) do
      {:ok, paginated_names} -> Util.paginate(conn, paginated_names)
      {:error, reason} -> Util.send_error(conn, :bad_request, reason)
    end
  end

  @spec search_v1(Conn.t(), map()) :: Conn.t()
  def search_v1(%Conn{assigns: %{state: state, opts: opts}} = conn, %{"prefix" => prefix}) do
    handle_input(conn, fn ->
      params = Map.put(query_groups(conn.query_string), "prefix", [prefix])

      json(
        conn,
        Enum.to_list(do_prefix_stream(state, validate_search_params!(params), opts))
      )
    end)
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

    {prev_cursor, names, next_cursor} =
      Names.search_names(state, lifecycles, prefix, pagination, cursor, opts)

    Util.paginate(conn, prev_cursor, names, next_cursor)
  end

  @spec name_claims(Conn.t(), map()) :: Conn.t()
  def name_claims(%Conn{assigns: assigns} = conn, %{"id" => name_id}) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor,
      scope: scope
    } = assigns

    case Names.fetch_name_claims(state, name_id, pagination, scope, cursor) do
      {:ok, {prev_cursor, names, next_cursor}} ->
        Util.paginate(conn, prev_cursor, names, next_cursor)

      {:error, reason} ->
        {:error, reason}
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

    case Names.fetch_name_transfers(state, name_id, pagination, scope, cursor) do
      {:ok, {prev_cursor, names, next_cursor}} ->
        Util.paginate(conn, prev_cursor, names, next_cursor)

      {:error, reason} ->
        {:error, reason}
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

    case Names.fetch_name_updates(state, name_id, pagination, scope, cursor) do
      {:ok, {prev_cursor, names, next_cursor}} ->
        Util.paginate(conn, prev_cursor, names, next_cursor)

      {:error, reason} ->
        {:error, reason}
    end
  end

  ##########

  defp name_reply(%Conn{assigns: %{state: state}} = conn, plain_name, opts) do
    case Name.locate(state, plain_name) do
      {info, source} -> json(conn, Format.to_map(state, info, source, expand?(opts)))
      nil -> raise ErrInput.NotFound, value: plain_name
    end
  end

  defp pointers_reply(%Conn{assigns: %{state: state}} = conn, plain_name) do
    case Name.locate(state, plain_name) do
      {m_name, Model.ActiveName} ->
        json(conn, Name.pointers(state, m_name))

      {_m_name, Model.InactiveName} ->
        raise ErrInput.Expired, value: plain_name

      _no_match? ->
        raise ErrInput.NotFound, value: plain_name
    end
  end

  defp pointees_reply(%Conn{assigns: %{state: state}} = conn, pubkey) do
    {active, inactive} = Name.pointees(state, pubkey)

    json(conn, %{
      "active" => Format.map_raw_values(active, &Format.to_json/1),
      "inactive" => Format.map_raw_values(inactive, &Format.to_json/1)
    })
  end

  defp auction_reply(%Conn{assigns: %{state: state}} = conn, plain_name, opts) do
    map_some(
      Name.locate_bid(state, plain_name),
      &json(conn, Format.to_map(state, &1, Model.AuctionBid, expand?(opts)))
    ) ||
      raise ErrInput.NotFound, value: plain_name
  end

  defp owned_by_reply(%Conn{assigns: %{state: state}} = conn, owner_pk, opts, active?) do
    query_res = Name.owned_by(state, owner_pk, active?)

    jsons = fn plains, source, locator ->
      for plain <- plains, reduce: [] do
        acc ->
          case locator.(plain) do
            {info, ^source} ->
              [Format.to_map(state, info, source, Keyword.get(opts, :expand?, false)) | acc]

            _not_found? ->
              acc
          end
      end
    end

    if active? do
      names = jsons.(query_res.names, Model.ActiveName, &Name.locate(state, &1))

      locator = fn plain_name ->
        case Name.locate_bid(state, plain_name) do
          nil -> :not_found
          auction_bid -> {auction_bid, Model.AuctionBid}
        end
      end

      top_bids = jsons.(query_res.top_bids, Model.AuctionBid, locator)

      json(conn, %{"active" => names, "top_bid" => top_bids})
    else
      names = jsons.(query_res.names, Model.InactiveName, &Name.locate(state, &1))

      json(conn, %{"inactive" => names})
    end
  end

  ##########

  defp do_prefix_stream(state, {prefix, lifecycles}, opts) do
    streams = Enum.map(lifecycles, &prefix_stream(state, &1, prefix, opts))

    case streams do
      [single] -> single
      [_ | _] -> merged_stream(streams, & &1["name"], :forward)
    end
  end

  ##########

  defp validate_search_params!(params),
    do: do_validate_search_params!(Map.delete(params, "expand"))

  defp do_validate_search_params!(%{"prefix" => [prefix], "only" => [_ | _] = lifecycles}) do
    {prefix,
     lifecycles
     |> Enum.map(fn
       "auction" -> :auction
       "active" -> :active
       "inactive" -> :inactive
       invalid -> raise ErrInput.Query, value: "name lifecycle #{invalid}"
     end)
     |> Enum.uniq()}
  end

  defp do_validate_search_params!(%{"prefix" => [prefix]}),
    do: {prefix, [:auction, :active, :inactive]}

  ##########

  defp prefix_stream(state, :auction, prefix, opts),
    do:
      DBS.Name.auction_prefix_resource(
        state,
        prefix,
        :forward,
        &Format.to_map(state, &1, Model.AuctionBid, expand?(opts))
      )

  defp prefix_stream(state, :active, prefix, opts),
    do:
      DBS.Name.prefix_resource(
        state,
        Model.ActiveName,
        prefix,
        :forward,
        &Format.to_map(state, &1, Model.ActiveName, expand?(opts))
      )

  defp prefix_stream(state, :inactive, prefix, opts),
    do:
      DBS.Name.prefix_resource(
        state,
        Model.InactiveName,
        prefix,
        :forward,
        &Format.to_map(state, &1, Model.InactiveName, expand?(opts))
      )
end

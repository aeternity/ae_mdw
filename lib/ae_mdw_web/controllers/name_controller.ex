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
  alias AeMdwWeb.Plugs.PaginatedPlug
  alias AeMdwWeb.Util
  alias Plug.Conn

  require Model

  import AeMdwWeb.Util
  import AeMdw.Util

  plug PaginatedPlug,
       [order_by: ~w(expiration deactivation name)a]
       when action in ~w(active_names inactive_names names auctions search search_v1)a

  @lifecycles_map %{
    "active" => :active,
    "inactive" => :inactive,
    "auction" => :auction
  }
  @lifecycles Map.keys(@lifecycles_map)

  @spec auction(Conn.t(), map()) :: Conn.t()
  def auction(conn, %{"id" => ident} = params),
    do:
      handle_input(conn, fn ->
        auction_reply(conn, Validate.plain_name!(ident), expand?(params))
      end)

  @spec pointers(Conn.t(), map()) :: Conn.t()
  def pointers(conn, %{"id" => ident}),
    do: handle_input(conn, fn -> pointers_reply(conn, Validate.plain_name!(ident)) end)

  @spec pointees(Conn.t(), map()) :: Conn.t()
  def pointees(conn, %{"id" => ident}),
    do: handle_input(conn, fn -> pointees_reply(conn, Validate.name_id!(ident)) end)

  @spec name(Conn.t(), map()) :: Conn.t()
  def name(conn, %{"id" => ident} = params),
    do:
      handle_input(conn, fn ->
        name_reply(conn, Validate.plain_name!(ident), expand?(params))
      end)

  @spec owned_by(Conn.t(), map()) :: Conn.t()
  def owned_by(conn, %{"id" => owner} = params),
    do:
      handle_input(conn, fn ->
        active? = Map.get(params, "active", "true") == "true"
        owned_by_reply(conn, Validate.id!(owner, [:account_pubkey]), expand?(params), active?)
      end)

  @spec auctions(Conn.t(), map()) :: Conn.t()
  def auctions(%Conn{assigns: assigns} = conn, _params) do
    %{pagination: pagination, cursor: cursor, expand?: expand?, order_by: order_by} = assigns

    {prev_cursor, auction_bids, next_cursor} =
      AuctionBids.fetch_auctions(pagination, order_by, cursor, expand?)

    Util.paginate(conn, prev_cursor, auction_bids, next_cursor)
  end

  @spec inactive_names(Conn.t(), map()) :: Conn.t()
  def inactive_names(%Conn{assigns: assigns} = conn, _params) do
    %{
      pagination: pagination,
      cursor: cursor,
      expand?: expand?,
      order_by: order_by,
      scope: scope
    } = assigns

    case Names.fetch_inactive_names(pagination, scope, order_by, cursor, expand?) do
      {:ok, prev_cursor, names, next_cursor} ->
        Util.paginate(conn, prev_cursor, names, next_cursor)

      {:error, reason} ->
        Util.send_error(conn, :bad_request, reason)
    end
  end

  @spec active_names(Conn.t(), map()) :: Conn.t()
  def active_names(%Conn{assigns: assigns} = conn, _params) do
    %{
      pagination: pagination,
      cursor: cursor,
      expand?: expand?,
      order_by: order_by,
      scope: scope
    } = assigns

    case Names.fetch_active_names(pagination, scope, order_by, cursor, expand?) do
      {:ok, prev_cursor, names, next_cursor} ->
        Util.paginate(conn, prev_cursor, names, next_cursor)

      {:error, reason} ->
        Util.send_error(conn, :bad_request, reason)
    end
  end

  @spec names(Conn.t(), map()) :: Conn.t()
  def names(%Conn{assigns: assigns, query_params: query} = conn, _params) do
    %{
      pagination: pagination,
      cursor: cursor,
      expand?: expand?,
      order_by: order_by,
      scope: scope
    } = assigns

    case Names.fetch_names(pagination, scope, order_by, query, cursor, expand?) do
      {:ok, prev_cursor, names, next_cursor} ->
        Util.paginate(conn, prev_cursor, names, next_cursor)

      {:error, reason} ->
        Util.send_error(conn, :bad_request, reason)
    end
  end

  @spec search_v1(Conn.t(), map()) :: Conn.t()
  def search_v1(conn, %{"prefix" => prefix}) do
    handle_input(conn, fn ->
      params = Map.put(query_groups(conn.query_string), "prefix", [prefix])
      json(conn, Enum.to_list(do_prefix_stream(validate_search_params!(params), expand?(params))))
    end)
  end

  @spec search(Conn.t(), map()) :: Conn.t()
  def search(%Conn{assigns: assigns, query_string: query_string} = conn, %{"prefix" => prefix}) do
    lifecycles =
      query_string
      |> URI.query_decoder()
      |> Enum.filter(&match?({"only", lifecycle} when lifecycle in @lifecycles, &1))
      |> Enum.map(fn {"only", lifecycle} -> Map.fetch!(@lifecycles_map, lifecycle) end)
      |> Enum.uniq()

    %{pagination: pagination, cursor: cursor, expand?: expand?} = assigns

    {prev_cursor, names, next_cursor} =
      Names.search_names(lifecycles, prefix, pagination, cursor, expand?)

    Util.paginate(conn, prev_cursor, names, next_cursor)
  end

  ##########

  defp name_reply(conn, plain_name, expand?) do
    case Name.locate(plain_name) do
      {info, source} -> json(conn, Format.to_map(info, source, expand?))
      nil -> raise ErrInput.NotFound, value: plain_name
    end
  end

  defp pointers_reply(conn, plain_name) do
    case Name.locate(plain_name) do
      {m_name, Model.ActiveName} ->
        json(conn, Format.map_raw_values(Name.pointers(m_name), &Format.to_json/1))

      {_, Model.InactiveName} ->
        raise ErrInput.Expired, value: plain_name

      _no_match? ->
        raise ErrInput.NotFound, value: plain_name
    end
  end

  defp pointees_reply(conn, pubkey) do
    {active, inactive} = Name.pointees(pubkey)

    json(conn, %{
      "active" => Format.map_raw_values(active, &Format.to_json/1),
      "inactive" => Format.map_raw_values(inactive, &Format.to_json/1)
    })
  end

  defp auction_reply(conn, plain_name, expand?) do
    map_some(
      Name.locate_bid(plain_name),
      &json(conn, Format.to_map(&1, Model.AuctionBid, expand?))
    ) ||
      raise ErrInput.NotFound, value: plain_name
  end

  defp owned_by_reply(conn, owner_pk, expand?, active?) do
    query_res = Name.owned_by(owner_pk, active?)

    jsons = fn plains, source, locator ->
      for plain <- plains, reduce: [] do
        acc ->
          case locator.(plain) do
            {info, ^source} -> [Format.to_map(info, source, expand?) | acc]
            _not_found? -> acc
          end
      end
    end

    if active? do
      names = jsons.(query_res.names, Model.ActiveName, &Name.locate/1)

      top_bids =
        jsons.(
          query_res.top_bids,
          Model.AuctionBid,
          &map_some(Name.locate_bid(&1), fn x -> {x, Model.AuctionBid} end)
        )

      json(conn, %{"active" => names, "top_bid" => top_bids})
    else
      names = jsons.(query_res.names, Model.InactiveName, &Name.locate/1)

      json(conn, %{"inactive" => names})
    end
  end

  ##########

  defp do_prefix_stream({prefix, lifecycles}, expand?) do
    streams = Enum.map(lifecycles, &prefix_stream(&1, prefix, expand?))

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

  defp prefix_stream(:auction, prefix, expand?),
    do:
      DBS.Name.auction_prefix_resource(
        prefix,
        :forward,
        &Format.to_map(&1, Model.AuctionBid, expand?)
      )

  defp prefix_stream(:active, prefix, expand?),
    do:
      DBS.Name.prefix_resource(
        Model.ActiveName,
        prefix,
        :forward,
        &Format.to_map(&1, Model.ActiveName, expand?)
      )

  defp prefix_stream(:inactive, prefix, expand?),
    do:
      DBS.Name.prefix_resource(
        Model.InactiveName,
        prefix,
        :forward,
        &Format.to_map(&1, Model.InactiveName, expand?)
      )
end

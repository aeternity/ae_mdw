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

  @spec auction_v2(Conn.t(), map()) :: Conn.t()
  def auction_v2(%Conn{assigns: %{state: state, opts: opts}} = conn, %{"id" => ident}),
    do:
      handle_input(conn, fn ->
        auction_reply(conn, Validate.plain_name!(state, ident), opts)
      end)

  @spec pointees(Conn.t(), map()) :: Conn.t()
  def pointees(%Conn{assigns: assigns} = conn, %{"account_id" => account_id}) do
    %{state: state, pagination: pagination, scope: scope, cursor: cursor} = assigns

    with {:ok, paginated_pointees} <-
           Names.fetch_pointees(state, account_id, pagination, scope, cursor) do
      Util.render(conn, paginated_pointees)
    end
  end

  @spec pointees_v2(Conn.t(), map()) :: Conn.t()
  def pointees_v2(conn, %{"id" => ident}),
    do: handle_input(conn, fn -> pointees_reply(conn, Validate.name_id!(ident)) end)

  @spec name(Conn.t(), map()) :: Conn.t()
  def name(%Conn{assigns: %{state: state, opts: opts}} = conn, %{"id" => ident}) do
    opts = [{:render_v3?, true} | opts]

    with {:ok, name} <- Names.fetch_name(state, ident, opts) do
      format_json(conn, name)
    end
  end

  @spec auction(Conn.t(), map()) :: Conn.t()
  def auction(%Conn{assigns: %{state: state, opts: opts}} = conn, %{"id" => ident}) do
    opts = [{:render_v3?, true} | opts]

    case AuctionBids.fetch(state, ident, opts) do
      {:ok, auction_bid} ->
        format_json(conn, auction_bid)

      :not_found ->
        {:error, ErrInput.NotFound.exception(value: ident)}
    end
  end

  @spec name_v2(Conn.t(), map()) :: Conn.t()
  def name_v2(%Conn{assigns: %{state: state, opts: opts}} = conn, %{"id" => ident}),
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

    Util.render(conn, paginated_auctions)
  end

  @spec auctions_v2(Conn.t(), map()) :: Conn.t()
  def auctions_v2(%Conn{assigns: assigns} = conn, _params) do
    %{state: state, pagination: pagination, cursor: cursor, opts: opts, order_by: order_by} =
      assigns

    paginated_auctions = AuctionBids.fetch_auctions(state, pagination, order_by, cursor, opts)
    Util.render(conn, paginated_auctions)
  end

  @spec auction_claims(Conn.t(), map()) :: Conn.t()
  def auction_claims(%Conn{assigns: assigns} = conn, %{"id" => name_id}) do
    %{state: state, pagination: pagination, cursor: cursor, scope: scope} = assigns

    with {:ok, paginated_bids} <-
           Names.fetch_auction_claims(state, name_id, pagination, scope, cursor) do
      Util.render(conn, paginated_bids)
    end
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

    with {:ok, names} <-
           Names.fetch_inactive_names(state, pagination, scope, order_by, cursor, opts) do
      Util.render(conn, names)
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

    with {:ok, names} <-
           Names.fetch_active_names(state, pagination, scope, order_by, cursor, opts) do
      Util.render(conn, names)
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
      Util.render(conn, names)
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
      Util.render(conn, names)
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
      Util.render(conn, paginated_history)
    end
  end

  @spec search_v1(Conn.t(), map()) :: Conn.t()
  def search_v1(%Conn{assigns: %{state: state, opts: opts}, query_string: query_string} = conn, %{
        "prefix" => prefix
      }) do
    params =
      query_string
      |> query_groups()
      |> Map.put("prefix", [prefix])
      |> Map.delete("expand")

    with {:ok, search_params} <- convert_params(params, &convert_search_param/1) do
      format_json(conn, Enum.to_list(do_prefix_stream(state, search_params, opts)))
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

    Util.render(conn, names)
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
      Util.render(conn, claims)
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
      Util.render(conn, transfers)
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
      Util.render(conn, updates)
    end
  end

  @spec name_account_claims(Conn.t(), map()) :: Conn.t()
  def name_account_claims(%Conn{assigns: assigns} = conn, %{
        "name" => name_or_hash,
        "account_id" => account_id
      }) do
    %{
      state: state,
      pagination: pagination,
      cursor: cursor,
      scope: scope
    } = assigns

    with {:ok, account_claims} <-
           Names.fetch_account_claims(state, account_id, name_or_hash, pagination, scope, cursor) do
      Util.render(conn, account_claims)
    end
  end

  ##########

  defp name_reply(%Conn{assigns: %{state: state}} = conn, plain_name, opts) do
    case Name.locate(state, plain_name) do
      {info, source} -> format_json(conn, Format.to_map(state, info, source, expand?(opts)))
      nil -> {:error, ErrInput.NotFound.exception(value: plain_name)}
    end
  end

  defp pointees_reply(%Conn{assigns: %{state: state}} = conn, pubkey) do
    {active, inactive} = Name.pointees(state, pubkey)

    format_json(conn, %{
      "active" => Format.map_raw_values(active, &Format.to_json/1),
      "inactive" => Format.map_raw_values(inactive, &Format.to_json/1)
    })
  end

  defp auction_reply(%Conn{assigns: %{state: state}} = conn, plain_name, opts) do
    case Name.locate_bid(state, plain_name) do
      nil ->
        {:error, ErrInput.NotFound.exception(value: plain_name)}

      auction_bid ->
        format_json(conn, Format.to_map(state, auction_bid, Model.AuctionBid, expand?(opts)))
    end
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

      format_json(conn, %{"active" => names, "top_bid" => top_bids})
    else
      names = jsons.(query_res.names, Model.InactiveName, &Name.locate(state, &1))

      format_json(conn, %{"inactive" => names})
    end
  end

  ##########

  defp do_prefix_stream(state, %{prefix: prefix} = filters, opts) do
    streams =
      filters
      |> Map.get(:lifecycles, ~w(active inactive auction)a)
      |> Enum.map(&prefix_stream(state, &1, prefix, opts))

    case streams do
      [single] -> single
      [_ | _] -> merged_stream(streams, & &1["name"], :forward)
    end
  end

  ##########

  defp convert_search_param({"prefix", prefix}), do: {:ok, {:prefix, [prefix]}}

  defp convert_search_param({"only", [_lifecycle | _rest] = lifecycles}) do
    lifecycles
    |> Enum.reduce_while({:ok, []}, fn
      "auction", {:ok, acc} ->
        {:cont, [:auction | acc]}

      "active", {:ok, acc} ->
        {:cont, [:active | acc]}

      "inactive", {:ok, acc} ->
        {:cont, [:inactive | acc]}

      invalid, _acc ->
        {:halt, {:error, ErrInput.Query.exception(value: "name lifecycle #{invalid}")}}
    end)
    |> case do
      {:ok, lifecycles} -> {:ok, {:lifecycles, Enum.uniq(lifecycles)}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp convert_search_param({key, val}),
    do: {:error, ErrInput.Query.exception(value: "#{key}=#{val}")}

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

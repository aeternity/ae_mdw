defmodule AeMdw.Names do
  @moduledoc """
  Context module for dealing with Names.
  """

  require AeMdw.Db.Model

  alias :aeser_api_encoder, as: Enc

  alias AeMdw.AuctionBids
  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.Util, as: DBUtil
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Util
  alias AeMdw.Validate

  @type cursor :: binary()
  # This needs to be an actual type like AeMdw.Db.Name.t()
  @type name :: term()
  @type plain_name() :: String.t()
  @type name_hash() :: binary()
  @type name_fee() :: non_neg_integer()
  @type auction_timeout :: non_neg_integer()
  @type ttl :: non_neg_integer()
  @type pointer :: term()
  @type pointers :: [pointer()]
  @type query :: %{binary() => binary()}

  @typep order_by :: :expiration | :name
  @typep pagination :: Collection.direction_limit()
  @typep range :: {:gen, Range.t()} | nil
  @typep reason :: binary()
  @typep lifecycle() :: :active | :inactive | :auction
  @typep prefix() :: plain_name()

  @table_active Model.ActiveName
  @table_active_expiration Model.ActiveNameExpiration
  @table_active_owner Model.ActiveNameOwner
  @table_inactive Model.InactiveName
  @table_inactive_expiration Model.InactiveNameExpiration
  @table_inactive_owner Model.InactiveNameowner

  @pagination_params ~w(limit cursor rev direction by scope)
  @states ~w(active inactive)
  @all_lifecycles ~w(active inactive auction)a

  @spec fetch_names(pagination(), range(), order_by(), query(), cursor() | nil, boolean()) ::
          {:ok, cursor() | nil, [name()], cursor() | nil} | {:error, reason()}
  def fetch_names(pagination, range, :expiration, query, cursor, expand?) do
    cursor = deserialize_expiration_cursor(cursor)
    scope = deserialize_scope(range)

    try do
      {prev_cursor, expiration_keys, next_cursor} =
        query
        |> Map.drop(@pagination_params)
        |> Enum.map(&convert_param/1)
        |> Map.new()
        |> build_expiration_streamer(scope, cursor)
        |> Collection.paginate(pagination)

      {:ok, serialize_expiration_cursor(prev_cursor), render_exp_list(expiration_keys, expand?),
       serialize_expiration_cursor(next_cursor)}
    rescue
      e in ErrInput ->
        {:error, e.message}
    end
  end

  def fetch_names(pagination, nil, :name, query, cursor, expand?) do
    cursor = deserialize_name_cursor(cursor)

    try do
      {prev_cursor, name_keys, next_cursor} =
        query
        |> Map.drop(@pagination_params)
        |> Enum.map(&convert_param/1)
        |> Map.new()
        |> build_name_streamer(cursor)
        |> Collection.paginate(pagination)

      {:ok, serialize_name_cursor(prev_cursor), render_names_list(name_keys, expand?),
       serialize_name_cursor(next_cursor)}
    rescue
      e in ErrInput ->
        {:error, e.message}
    end
  end

  def fetch_names(_pagination, _range, :name, _query, _cursor, _expand?) do
    try do
      raise(ErrInput.Query, value: "can't scope names sorted by name")
    rescue
      e in ErrInput ->
        {:error, e.message}
    end
  end

  defp build_name_streamer(%{owned_by: owner_pk, state: "active"}, cursor) do
    cursor = if cursor, do: {owner_pk, cursor}

    fn direction ->
      @table_active_owner
      |> Collection.stream(direction, nil, cursor)
      |> Stream.map(fn key -> {key, :active} end)
    end
  end

  defp build_name_streamer(%{owned_by: owner_pk, state: "inactive"}, cursor) do
    cursor = if cursor, do: {owner_pk, cursor}

    fn direction ->
      @table_inactive_owner
      |> Collection.stream(direction, nil, cursor)
      |> Stream.map(fn key -> {key, :inactive} end)
    end
  end

  defp build_name_streamer(%{state: "inactive"}, cursor) do
    fn direction ->
      @table_inactive
      |> Collection.stream(direction, nil, cursor)
      |> Stream.map(fn key -> {key, :inactive} end)
    end
  end

  defp build_name_streamer(%{state: "active"}, cursor) do
    fn direction ->
      @table_active
      |> Collection.stream(direction, nil, cursor)
      |> Stream.map(fn key -> {key, :active} end)
    end
  end

  defp build_name_streamer(_query, cursor) do
    fn direction ->
      active_stream =
        @table_active
        |> Collection.stream(direction, nil, cursor)
        |> Stream.map(fn key -> {key, :active} end)

      inactive_stream =
        @table_inactive
        |> Collection.stream(direction, nil, cursor)
        |> Stream.map(fn key -> {key, :inactive} end)

      Collection.merge([active_stream, inactive_stream], direction)
    end
  end

  defp build_expiration_streamer(%{owned_by: _owner_pk}, _scope, _cursor) do
    raise(ErrInput.Query, value: "can't order by expiration when filtering by owner")
  end

  defp build_expiration_streamer(%{state: "active"}, scope, cursor) do
    fn direction ->
      @table_active_expiration
      |> Collection.stream(direction, scope, cursor)
      |> Stream.map(&{&1, :active})
    end
  end

  defp build_expiration_streamer(%{state: "inactive"}, scope, cursor) do
    fn direction ->
      @table_inactive_expiration
      |> Collection.stream(direction, scope, cursor)
      |> Stream.map(&{&1, :inactive})
    end
  end

  defp build_expiration_streamer(_query, scope, cursor) do
    fn direction ->
      active_stream =
        @table_active_expiration
        |> Collection.stream(direction, scope, cursor)
        |> Stream.map(fn key -> {key, :active} end)

      inactive_stream =
        @table_inactive_expiration
        |> Collection.stream(direction, scope, cursor)
        |> Stream.map(fn key -> {key, :inactive} end)

      case direction do
        :forward -> Stream.concat(inactive_stream, active_stream)
        :backward -> Stream.concat(active_stream, inactive_stream)
      end
    end
  end

  @spec fetch_active_names(pagination(), range(), order_by(), cursor() | nil, boolean()) ::
          {:ok, cursor() | nil, [name()], cursor() | nil} | {:error, reason()}
  def fetch_active_names(pagination, range, order_by, cursor, expand?),
    do: fetch_names(pagination, range, order_by, %{"state" => "active"}, cursor, expand?)

  @spec fetch_inactive_names(pagination(), range(), order_by(), cursor() | nil, boolean()) ::
          {:ok, cursor() | nil, [name()], cursor() | nil} | {:error, reason()}
  def fetch_inactive_names(pagination, range, order_by, cursor, expand?),
    do: fetch_names(pagination, range, order_by, %{"state" => "inactive"}, cursor, expand?)

  @spec search_names([lifecycle()], prefix(), pagination(), cursor() | nil, boolean()) ::
          {cursor() | nil, [name()], cursor() | nil}

  def search_names([], prefix, pagination, cursor, expand?),
    do: search_names(@all_lifecycles, prefix, pagination, cursor, expand?)

  def search_names(lifecycles, prefix, pagination, cursor, expand?) do
    cursor = deserialize_name_cursor(cursor)
    scope = {prefix, prefix <> Util.max_256bit_bin()}

    {prev_cursor, name_keys, next_cursor} =
      fn direction ->
        lifecycles
        |> Enum.map(fn
          :active ->
            @table_active
            |> Collection.stream(direction, scope, cursor)
            |> Stream.map(&{&1, :active})

          :inactive ->
            @table_inactive
            |> Collection.stream(direction, scope, cursor)
            |> Stream.map(&{&1, :inactive})

          :auction ->
            prefix
            |> AuctionBids.auctions_stream(direction, scope, cursor)
            |> Stream.map(&{&1, :auction})
        end)
        |> Collection.merge(direction)
      end
      |> Collection.paginate(pagination)

    {serialize_name_cursor(prev_cursor), render_search_list(name_keys, expand?),
     serialize_name_cursor(next_cursor)}
  end

  @spec fetch_previous_list(plain_name()) :: [name()]
  def fetch_previous_list(plain_name) do
    case Database.fetch(@table_inactive, plain_name) do
      {:ok, name} ->
        name
        |> Stream.unfold(fn
          nil -> nil
          Model.name(previous: previous) = name -> {render_name_info(name, false), previous}
        end)
        |> Enum.to_list()

      :not_found ->
        []
    end
  end

  defp render_exp_list(names_tables_keys, expand?) do
    Enum.map(names_tables_keys, fn {{_exp, plain_name}, source} ->
      render(plain_name, source == :active, expand?)
    end)
  end

  defp render_names_list(names_tables_keys, expand?) do
    Enum.map(names_tables_keys, fn {plain_name, source} ->
      render(plain_name, source == :active, expand?)
    end)
  end

  defp render_search_list(names_tables_keys, expand?) do
    Enum.map(names_tables_keys, fn
      {plain_name, :auction} ->
        %{"type" => "auction", "payload" => AuctionBids.fetch!(plain_name, expand?)}

      {plain_name, source} ->
        %{"type" => "name", "payload" => render(plain_name, source == :active, expand?)}
    end)
  end

  defp render(plain_name, is_active?, expand?) do
    name = Database.fetch!(if(is_active?, do: @table_active, else: @table_inactive), plain_name)

    name_hash =
      case :aens.get_name_hash(plain_name) do
        {:ok, name_id_bin} -> Enc.encode(:name, name_id_bin)
        _error -> nil
      end

    {status, auction_bid} =
      case AuctionBids.top_auction_bid(plain_name, expand?) do
        {:ok, auction_bid} ->
          {_version, auction_bid} = pop_in(auction_bid, [:info, :last_bid, "tx", "version"])
          {:auction, auction_bid}

        :not_found ->
          {:name, nil}
      end

    %{
      name: plain_name,
      hash: name_hash,
      auction: auction_bid && auction_bid.info,
      status: to_string(status),
      active: is_active?,
      info: render_name_info(name, expand?),
      previous: render_previous(name, expand?)
    }
  end

  defp render_name_info(
         Model.name(
           active: active,
           expire: expire,
           claims: claims,
           updates: updates,
           transfers: transfers,
           revoke: revoke,
           auction_timeout: auction_timeout
         ) = name,
         expand?
       ) do
    %{
      active_from: active,
      expire_height: expire,
      claims: Enum.map(claims, &expand_txi(Format.bi_txi_txi(&1), expand?)),
      updates: Enum.map(updates, &expand_txi(Format.bi_txi_txi(&1), expand?)),
      transfers: Enum.map(transfers, &expand_txi(Format.bi_txi_txi(&1), expand?)),
      revoke: (revoke && expand_txi(Format.bi_txi_txi(revoke), expand?)) || nil,
      auction_timeout: auction_timeout,
      pointers: render_pointers(name),
      ownership: render_ownership(name)
    }
  end

  defp render_pointers(name) do
    name
    |> Name.pointers()
    |> Enum.reverse()
    |> Enum.at(0)
    |> case do
      {_k, id} -> %{"account_pubkey" => Format.enc_id(id)}
      nil -> %{}
    end
  end

  defp render_ownership(name) do
    %{current: current_owner, original: original_owner} = Name.ownership(name)

    %{
      current: Format.enc_id(current_owner),
      original: Format.enc_id(original_owner)
    }
  end

  defp serialize_name_cursor(nil), do: nil

  defp serialize_name_cursor({{name, _tab}, is_reversed?}),
    do: serialize_name_cursor({name, is_reversed?})

  defp serialize_name_cursor({name, is_reversed?}), do: {name, is_reversed?}

  defp deserialize_name_cursor(nil), do: nil

  defp deserialize_name_cursor(cursor_bin) do
    case Regex.run(~r/\A([\w\.]+\.chain)\z/, cursor_bin) do
      [_match0, name] -> name
      nil -> nil
    end
  end

  defp serialize_expiration_cursor(nil), do: nil

  defp serialize_expiration_cursor({{{exp_height, name}, _tab}, is_reversed?}),
    do: serialize_expiration_cursor({{exp_height, name}, is_reversed?})

  defp serialize_expiration_cursor({{exp_height, name}, is_reversed?}),
    do: {"#{exp_height}-#{name}", is_reversed?}

  defp deserialize_expiration_cursor(nil), do: nil

  defp deserialize_expiration_cursor(cursor_bin) do
    case Regex.run(~r/\A(\d+)-([\w\.]+)\z/, cursor_bin) do
      [_match0, exp_height, name] -> {String.to_integer(exp_height), name}
      nil -> nil
    end
  end

  defp expand_txi(bi_txi, false), do: bi_txi
  defp expand_txi(bi_txi, true), do: Format.to_map(DBUtil.read_tx!(bi_txi))

  defp render_previous(name, expand?) do
    name
    |> Stream.unfold(fn
      Model.name(previous: nil) -> nil
      Model.name(previous: previous) -> {previous, previous}
    end)
    |> Enum.map(&render_name_info(&1, expand?))
  end

  defp deserialize_scope({:gen, %Range{first: first_gen, last: last_gen}}) do
    {{first_gen, Util.min_bin()}, {last_gen, Util.max_256bit_bin()}}
  end

  defp deserialize_scope(_nil_or_txis_scope), do: nil

  defp convert_param({"owned_by", account_id}) when is_binary(account_id),
    do: {:owned_by, Validate.id!(account_id, [:account_pubkey])}

  defp convert_param({"state", state}) when state in @states, do: {:state, state}

  defp convert_param(other_param),
    do: raise(ErrInput.Query, value: other_param)
end

defmodule AeMdw.Names do
  @moduledoc """
  Context module for dealing with Names.
  """

  require AeMdw.Db.Model

  alias :aeser_api_encoder, as: Enc

  alias AeMdw.AuctionBids
  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Util
  alias AeMdw.Validate

  @type cursor() :: binary() | nil
  @type page_cursor() :: Collection.pagination_cursor()
  # This needs to be an actual type like AeMdw.Db.Name.t()
  @type name :: term()
  @type history_item :: claim() | update() | transfer() | revoke()
  @type claim() :: map()
  @type update() :: map()
  @type transfer() :: map()
  @type revoke() :: map()
  @type plain_name() :: String.t()
  @type name_hash() :: binary()
  @type name_fee() :: non_neg_integer()
  @type auction_timeout :: non_neg_integer()
  @type ttl :: non_neg_integer()
  @type pointer :: term()
  @type pointers :: [pointer()]
  @type query :: %{binary() => binary()}

  @typep state() :: State.t()
  @typep order_by :: :expiration | :name
  @typep pagination :: Collection.direction_limit()
  @typep range :: {:gen, Range.t()} | nil
  @typep reason :: binary()
  @typep lifecycle() :: :active | :inactive | :auction
  @typep prefix() :: plain_name()
  @typep opts() :: Util.opts()
  @type nested_cursor() :: Blocks.bi_txi()

  @table_active Model.ActiveName
  @table_activation Model.ActiveNameActivation
  @table_active_expiration Model.ActiveNameExpiration
  @table_active_owner Model.ActiveNameOwner
  @table_active_owner_deactivation Model.ActiveNameOwnerDeactivation
  @table_inactive_owner_deactivation Model.InactiveNameOwnerDeactivation
  @table_inactive Model.InactiveName
  @table_inactive_expiration Model.InactiveNameExpiration
  @table_inactive_owner Model.InactiveNameOwner

  @pagination_params ~w(limit cursor rev direction scope tx_hash expand)
  @states ~w(active inactive)
  @all_lifecycles ~w(active inactive auction)a

  @min_int Util.min_int()
  @max_int Util.max_int()
  @min_bin Util.min_bin()
  @max_bin Util.max_256bit_bin()

  @spec fetch_names(state(), pagination(), range(), order_by(), query(), cursor() | nil, opts()) ::
          {:ok, {page_cursor(), [name()], page_cursor()}} | {:error, reason()}
  def fetch_names(state, pagination, range, order_by, query, cursor, opts)
      when order_by in [:activation, :expiration, :deactivation] do
    cursor = deserialize_height_cursor(cursor)
    scope = deserialize_scope(range)

    try do
      {prev_cursor, height_keys, next_cursor} =
        query
        |> Map.drop(@pagination_params)
        |> Map.new(&convert_param/1)
        |> build_height_streamer(state, scope, cursor)
        |> Collection.paginate(pagination)

      {:ok,
       {serialize_height_cursor(prev_cursor), render_height_list(state, height_keys, opts),
        serialize_height_cursor(next_cursor)}}
    rescue
      e in ErrInput ->
        {:error, e.message}
    end
  end

  def fetch_names(state, pagination, nil, :name, query, cursor, opts) do
    cursor = deserialize_name_cursor(cursor)

    try do
      {prev_cursor, name_keys, next_cursor} =
        query
        |> Map.drop(@pagination_params)
        |> Map.new(&convert_param/1)
        |> build_name_streamer(state, cursor)
        |> Collection.paginate(pagination)

      {:ok,
       {serialize_name_cursor(prev_cursor), render_names_list(state, name_keys, opts),
        serialize_name_cursor(next_cursor)}}
    rescue
      e in ErrInput ->
        {:error, e.message}
    end
  end

  def fetch_names(_state, _pagination, _range, :name, _query, _cursor, _opts) do
    try do
      raise(ErrInput.Query, value: "can't scope names sorted by name")
    rescue
      e in ErrInput ->
        {:error, e.message}
    end
  end

  @spec fetch_name_history(state(), pagination(), plain_name(), cursor()) ::
          {:ok, {page_cursor(), [history_item()], page_cursor()}} | {:error, reason()}
  def fetch_name_history(state, plain_name, pagination, cursor) do
    try do
      cursor = deserialize_history_cursor(plain_name, cursor)

      {prev_cursor, history_keys, next_cursor} =
        state
        |> build_history_streamer(plain_name, cursor)
        |> Collection.paginate(pagination)

      {:ok,
       {
         serialize_history_cursor(plain_name, prev_cursor),
         render_history(state, history_keys),
         serialize_history_cursor(plain_name, next_cursor)
       }}
    rescue
      e in ErrInput ->
        {:error, e.message}
    end
  end

  @spec fetch_name_claims(state(), binary(), pagination(), range(), cursor() | nil) ::
          {:ok, {page_cursor(), [claim()], page_cursor()}} | {:error, Error.t()}
  def fetch_name_claims(state, plain_name_or_hash, pagination, scope, cursor) do
    with {:ok, name_or_auction} <- locate_name_or_auction(state, plain_name_or_hash) do
      {plain_name, nested_table, height} =
        case name_or_auction do
          Model.name(index: plain_name, active: active) ->
            {plain_name, Model.NameClaim, active}

          Model.auction_bid(index: plain_name, expire_height: expire_height) ->
            {plain_name, Model.AuctionBidClaim, expire_height}
        end

      {prev_cursor, claims, next_cursor} =
        paginate_nested_resource(
          state,
          nested_table,
          plain_name,
          height,
          scope,
          cursor,
          pagination
        )

      {:ok, {prev_cursor, Enum.map(claims, &render_claim(state, &1)), next_cursor}}
    end
  end

  @spec fetch_auction_claims(state(), binary(), pagination(), range(), cursor() | nil) ::
          {:ok, {page_cursor(), [claim()], page_cursor()}} | {:error, Error.t()}
  def fetch_auction_claims(state, plain_name_or_hash, pagination, scope, cursor) do
    case locate_name_or_auction(state, plain_name_or_hash) do
      {:ok, Model.auction_bid(index: plain_name, expire_height: expire_height)} ->
        {prev_cursor, claims, next_cursor} =
          paginate_nested_resource(
            state,
            Model.AuctionBidClaim,
            plain_name,
            expire_height,
            scope,
            cursor,
            pagination
          )

        {:ok, {prev_cursor, Enum.map(claims, &render_claim(state, &1)), next_cursor}}

      {:error, reason} ->
        {:error, reason}

      {:ok, Model.name()} ->
        {:error, ErrInput.NotFound.exception(value: plain_name_or_hash)}
    end
  end

  @spec fetch_name_updates(state(), binary(), pagination(), range(), cursor()) ::
          {:ok, {page_cursor(), [update()], page_cursor()}} | {:error, Error.t()}
  def fetch_name_updates(state, plain_name_or_hash, pagination, scope, cursor) do
    case locate_name_or_auction(state, plain_name_or_hash) do
      {:ok, Model.name(index: plain_name, active: active)} ->
        {prev_cursor, updates, next_cursor} =
          paginate_nested_resource(
            state,
            Model.NameUpdate,
            plain_name,
            active,
            scope,
            cursor,
            pagination
          )

        {:ok, {prev_cursor, Enum.map(updates, &render_update(state, &1)), next_cursor}}

      {:ok, Model.auction_bid()} ->
        {:error, ErrInput.NotFound.exception(value: plain_name_or_hash)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec fetch_name_transfers(state(), binary(), pagination(), range(), cursor() | nil) ::
          {:ok, {page_cursor(), [update()], page_cursor()}} | {:error, Error.t()}
  def fetch_name_transfers(state, plain_name_or_hash, pagination, scope, cursor) do
    case locate_name_or_auction(state, plain_name_or_hash) do
      {:ok, Model.name(index: plain_name, active: active)} ->
        {prev_cursor, updates, next_cursor} =
          paginate_nested_resource(
            state,
            Model.NameTransfer,
            plain_name,
            active,
            scope,
            cursor,
            pagination
          )

        {:ok, {prev_cursor, Enum.map(updates, &render_transfer(state, &1)), next_cursor}}

      {:ok, Model.auction_bid()} ->
        {:error, ErrInput.NotFound.exception(value: plain_name_or_hash)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec expire_after(Blocks.height()) :: Blocks.height()
  def expire_after(auction_end) do
    auction_end + :aec_governance.name_claim_max_expiration(Db.proto_vsn(auction_end))
  end

  defp build_name_streamer(%{owned_by: owner_pk, state: "active"}, state, cursor) do
    cursor = if cursor, do: {owner_pk, cursor}
    scope = {{owner_pk, Util.min_bin()}, {owner_pk, Util.max_256bit_bin()}}

    fn direction ->
      state
      |> Collection.stream(@table_active_owner, direction, scope, cursor)
      |> Stream.map(fn {^owner_pk, plain_name} -> {plain_name, :active} end)
    end
  end

  defp build_name_streamer(%{owned_by: owner_pk, state: "inactive"}, state, cursor) do
    cursor = if cursor, do: {owner_pk, cursor}
    scope = {{owner_pk, Util.min_bin()}, {owner_pk, Util.max_256bit_bin()}}

    fn direction ->
      state
      |> Collection.stream(@table_inactive_owner, direction, scope, cursor)
      |> Stream.map(fn {_owner_pk, plain_name} -> {plain_name, :inactive} end)
    end
  end

  defp build_name_streamer(%{state: "inactive"}, state, cursor) do
    fn direction ->
      state
      |> Collection.stream(@table_inactive, direction, nil, cursor)
      |> Stream.map(fn key -> {key, :inactive} end)
    end
  end

  defp build_name_streamer(%{state: "active"}, state, cursor) do
    fn direction ->
      state
      |> Collection.stream(@table_active, direction, nil, cursor)
      |> Stream.map(fn key -> {key, :active} end)
    end
  end

  defp build_name_streamer(%{owned_by: owner_pk}, state, cursor) do
    fn direction ->
      Collection.merge(
        [
          build_name_streamer(%{owned_by: owner_pk, state: "active"}, state, cursor).(direction),
          build_name_streamer(%{owned_by: owner_pk, state: "inactive"}, state, cursor).(direction)
        ],
        direction
      )
    end
  end

  defp build_name_streamer(_query, state, cursor) do
    fn direction ->
      active_stream =
        state
        |> Collection.stream(@table_active, direction, nil, cursor)
        |> Stream.map(fn key -> {key, :active} end)

      inactive_stream =
        state
        |> Collection.stream(@table_inactive, direction, nil, cursor)
        |> Stream.map(fn key -> {key, :inactive} end)

      Collection.merge([active_stream, inactive_stream], direction)
    end
  end

  defp build_height_streamer(%{owned_by: owner_pk, state: "active"}, state, scope, cursor) do
    key_boundary = serialize_owner_deactivation_key_boundary(owner_pk, scope)
    cursor = serialize_owner_deactivation_cursor(owner_pk, cursor)

    fn direction ->
      state
      |> Collection.stream(@table_active_owner_deactivation, direction, key_boundary, cursor)
      |> Stream.map(fn {^owner_pk, deactivation_height, plain_name} ->
        {{deactivation_height, plain_name}, :active}
      end)
    end
  end

  defp build_height_streamer(%{owned_by: owner_pk, state: "inactive"}, state, scope, cursor) do
    key_boundary = serialize_owner_deactivation_key_boundary(owner_pk, scope)
    cursor = serialize_owner_deactivation_cursor(owner_pk, cursor)

    fn direction ->
      state
      |> Collection.stream(@table_inactive_owner_deactivation, direction, key_boundary, cursor)
      |> Stream.map(fn {^owner_pk, deactivation_height, plain_name} ->
        {{deactivation_height, plain_name}, :inactive}
      end)
    end
  end

  defp build_height_streamer(%{owned_by: owner_pk}, state, scope, cursor) do
    key_boundary = serialize_owner_deactivation_key_boundary(owner_pk, scope)
    cursor = serialize_owner_deactivation_cursor(owner_pk, cursor)

    fn direction ->
      active_stream =
        state
        |> Collection.stream(@table_active_owner_deactivation, direction, key_boundary, cursor)
        |> Stream.map(fn {^owner_pk, deactivation_height, plain_name} ->
          {deactivation_height, plain_name, :active}
        end)

      inactive_stream =
        state
        |> Collection.stream(@table_inactive_owner_deactivation, direction, key_boundary, cursor)
        |> Stream.map(fn {^owner_pk, deactivation_height, plain_name} ->
          {deactivation_height, plain_name, :inactive}
        end)

      [
        active_stream,
        inactive_stream
      ]
      |> Collection.merge(direction)
      |> Stream.map(fn {deactivation_height, plain_name, source} ->
        {{deactivation_height, plain_name}, source}
      end)
    end
  end

  defp build_height_streamer(%{state: "active", by: "activation"}, state, scope, cursor) do
    fn direction ->
      state
      |> Collection.stream(@table_activation, direction, scope, cursor)
      |> Stream.map(&{&1, :active})
    end
  end

  defp build_height_streamer(%{state: "active"}, state, scope, cursor) do
    fn direction ->
      state
      |> Collection.stream(@table_active_expiration, direction, scope, cursor)
      |> Stream.map(&{&1, :active})
    end
  end

  defp build_height_streamer(%{state: "inactive"}, state, scope, cursor) do
    fn direction ->
      state
      |> Collection.stream(@table_inactive_expiration, direction, scope, cursor)
      |> Stream.map(&{&1, :inactive})
    end
  end

  defp build_height_streamer(%{by: "activation"}, _state, _scope, _cursor) do
    raise(ErrInput.Query, value: "can only order by activation when filtering active names")
  end

  defp build_height_streamer(_query, state, scope, cursor) do
    fn direction ->
      active_stream =
        state
        |> Collection.stream(@table_active_expiration, direction, scope, cursor)
        |> Stream.map(fn key -> {key, :active} end)

      inactive_stream =
        state
        |> Collection.stream(@table_inactive_expiration, direction, scope, cursor)
        |> Stream.map(fn key -> {key, :inactive} end)

      case direction do
        :forward -> Stream.concat(inactive_stream, active_stream)
        :backward -> Stream.concat(active_stream, inactive_stream)
      end
    end
  end

  defp build_history_streamer(state, plain_name, cursor) do
    fn direction ->
      Collection.merge(
        [
          Name.stream_nested_resource(
            state,
            Model.NameClaim,
            direction,
            plain_name,
            cursor
          ),
          Name.stream_nested_resource(
            state,
            Model.NameRevoke,
            direction,
            plain_name,
            cursor
          ),
          Name.stream_nested_resource(
            state,
            Model.NameUpdate,
            direction,
            plain_name,
            cursor
          ),
          Name.stream_nested_resource(
            state,
            Model.NameTransfer,
            direction,
            plain_name,
            cursor
          )
        ],
        direction
      )
    end
  end

  @spec fetch_active_names(state(), pagination(), range(), order_by(), cursor(), opts()) ::
          {:ok, {page_cursor(), [name()], page_cursor()}} | {:error, reason()}
  def fetch_active_names(state, pagination, range, order_by, cursor, opts),
    do: fetch_names(state, pagination, range, order_by, %{"state" => "active"}, cursor, opts)

  @spec fetch_inactive_names(state(), pagination(), range(), order_by(), cursor(), opts()) ::
          {:ok, {page_cursor(), [name()], page_cursor()}} | {:error, reason()}
  def fetch_inactive_names(state, pagination, range, order_by, cursor, opts),
    do: fetch_names(state, pagination, range, order_by, %{"state" => "inactive"}, cursor, opts)

  @spec search_names(state(), [lifecycle()], prefix(), pagination(), cursor(), opts()) ::
          {page_cursor(), [name()], page_cursor()}

  def search_names(state, [], prefix, pagination, cursor, opts),
    do: search_names(state, @all_lifecycles, prefix, pagination, cursor, opts)

  def search_names(state, lifecycles, prefix, pagination, cursor, opts) do
    cursor = deserialize_name_cursor(cursor)
    scope = {prefix, prefix <> Util.max_256bit_bin()}

    {prev_cursor, name_keys, next_cursor} =
      fn direction ->
        lifecycles
        |> Enum.map(fn
          :active ->
            state
            |> Collection.stream(@table_active, direction, scope, cursor)
            |> Stream.map(&{&1, :active})

          :inactive ->
            state
            |> Collection.stream(@table_inactive, direction, scope, cursor)
            |> Stream.map(&{&1, :inactive})

          :auction ->
            state
            |> AuctionBids.auctions_stream(prefix, direction, scope, cursor)
            |> Stream.map(&{&1, :auction})
        end)
        |> Collection.merge(direction)
      end
      |> Collection.paginate(pagination)

    {serialize_name_cursor(prev_cursor), render_search_list(state, name_keys, opts),
     serialize_name_cursor(next_cursor)}
  end

  @spec fetch_previous_list(state(), plain_name()) :: [name()]
  def fetch_previous_list(state, plain_name) do
    {last_gen, last_micro_time} = DbUtil.last_gen_and_time(state)

    case State.get(state, @table_inactive, plain_name) do
      {:ok, name} ->
        name
        |> Stream.unfold(fn
          nil ->
            nil

          Model.name(previous: previous) = name ->
            {render_name_info(state, name, last_gen, last_micro_time, []), previous}
        end)
        |> Enum.to_list()

      :not_found ->
        []
    end
  end

  @spec revoke_or_expire_height(Model.name()) :: Blocks.height()
  def revoke_or_expire_height(m_name) do
    case {Model.name(m_name, :revoke), Model.name(m_name, :expire)} do
      {nil, expire} -> expire
      {{{revoke_height, _revoke_mbi}, _revoke_txi}, _expire} -> revoke_height
    end
  end

  defp render_height_list(state, names_tables_keys, opts) do
    names_tables_keys =
      names_tables_keys
      |> Enum.map(fn {{_exp, plain_name}, source} -> {plain_name, source} end)

    render_names_list(state, names_tables_keys, opts)
  end

  defp render_names_list(state, names_tables_keys, opts) do
    {last_gen, last_micro_time} = DbUtil.last_gen_and_time(state)

    Enum.map(names_tables_keys, fn {plain_name, source} ->
      render(state, plain_name, source == :active, last_gen, last_micro_time, opts)
    end)
  end

  defp render_search_list(state, names_tables_keys, opts) do
    {last_gen, last_micro_time} = DbUtil.last_gen_and_time(state)

    Enum.map(names_tables_keys, fn
      {plain_name, :auction} ->
        %{"type" => "auction", "payload" => AuctionBids.fetch!(state, plain_name, opts)}

      {plain_name, source} ->
        %{
          "type" => "name",
          "payload" =>
            render(state, plain_name, source == :active, last_gen, last_micro_time, opts)
        }
    end)
  end

  defp render(state, plain_name, is_active?, last_gen, last_micro_time, opts) do
    if Keyword.get(opts, :render_v3?, false) do
      render_v3(state, plain_name, is_active?, last_gen, last_micro_time, opts)
    else
      render_v2(state, plain_name, is_active?, last_gen, last_micro_time, opts)
    end
  end

  defp render_v3(state, plain_name, is_active?, last_gen, last_micro_time, opts) do
    Model.name(active: active, expire: expire, revoke: revoke, auction_timeout: auction_timeout) =
      name =
      State.fetch!(state, if(is_active?, do: @table_active, else: @table_inactive), plain_name)

    name_hash =
      case :aens.get_name_hash(plain_name) do
        {:ok, name_id_bin} -> Enc.encode(:name, name_id_bin)
        _error -> nil
      end

    {status, auction_bid} =
      case AuctionBids.fetch(state, plain_name, opts) do
        {:ok, auction_bid} ->
          {_version, auction_bid} = pop_in(auction_bid, [:last_bid, "tx", "version"])
          {"auction", auction_bid}

        :not_found ->
          {"name", nil}
      end

    %{
      name: plain_name,
      hash: name_hash,
      auction: auction_bid,
      status: status,
      active: is_active?,
      active_from: active,
      expire_height: expire,
      approximate_expire_time: DbUtil.height_to_time(state, expire, last_gen, last_micro_time),
      revoke: revoke && expand_txi_idx(state, revoke, opts),
      auction_timeout: auction_timeout,
      ownership: render_ownership(state, name)
    }
  end

  defp render_v2(state, plain_name, is_active?, last_gen, last_micro_time, opts) do
    name =
      State.fetch!(state, if(is_active?, do: @table_active, else: @table_inactive), plain_name)

    name_hash =
      case :aens.get_name_hash(plain_name) do
        {:ok, name_id_bin} -> Enc.encode(:name, name_id_bin)
        _error -> nil
      end

    {status, auction_bid} =
      case AuctionBids.fetch(state, plain_name, opts) do
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
      info: render_name_info(state, name, last_gen, last_micro_time, opts),
      previous: render_previous(state, name, last_gen, last_micro_time, opts)
    }
  end

  defp render_name_info(
         state,
         Model.name(
           index: plain_name,
           active: active,
           expire: expire,
           revoke: revoke,
           auction_timeout: auction_timeout
         ) = name,
         last_gen,
         last_micro_time,
         opts
       ) do
    claims = Name.stream_nested_resource(state, Model.NameClaim, plain_name, active)
    updates = Name.stream_nested_resource(state, Model.NameUpdate, plain_name, active)
    transfers = Name.stream_nested_resource(state, Model.NameTransfer, plain_name, active)

    %{
      active_from: active,
      expire_height: expire,
      approximate_expire_time: DbUtil.height_to_time(state, expire, last_gen, last_micro_time),
      claims: Enum.map(claims, &expand_txi_idx(state, &1, opts)),
      updates: Enum.map(updates, &expand_txi_idx(state, &1, opts)),
      transfers: Enum.map(transfers, &expand_txi_idx(state, &1, opts)),
      revoke: (revoke && expand_txi_idx(state, revoke, opts)) || nil,
      auction_timeout: auction_timeout,
      pointers: Name.pointers(state, name),
      ownership: render_ownership(state, name)
    }
  end

  defp render_history(state, name_operations) do
    Enum.map(name_operations, &render_nested_resource(state, &1))
  end

  defp render_ownership(state, name) do
    %{current: current_owner, original: original_owner} = Name.ownership(state, name)

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
    if Regex.match?(~r/\A[-\w\.]+\z/, cursor_bin) do
      cursor_bin
    else
      nil
    end
  end

  defp serialize_height_cursor(nil), do: nil

  defp serialize_height_cursor({{{height, name}, _tab}, is_reversed?}),
    do: serialize_height_cursor({{height, name}, is_reversed?})

  defp serialize_height_cursor({{height, name}, is_reversed?}),
    do: {Base.encode64(:erlang.term_to_binary({height, name}), padding: false), is_reversed?}

  defp deserialize_height_cursor(nil), do: nil

  defp deserialize_height_cursor(cursor_bin) do
    with {:ok, base64_decoded} <- Base.decode64(cursor_bin, padding: false),
         {height, name} when is_integer(height) and is_binary(name) <-
           :erlang.binary_to_term(base64_decoded) do
      {height, name}
    else
      _invalid -> nil
    end
  end

  defp serialize_history_cursor(_name, nil), do: nil

  defp serialize_history_cursor(name, {{{height, txi_idx}, _table}, is_reversed?}) do
    cursor_bin = :erlang.term_to_binary({name, height, txi_idx})
    {Base.encode64(cursor_bin, padding: false), is_reversed?}
  end

  defp deserialize_history_cursor(_name, nil), do: nil

  defp deserialize_history_cursor(name, cursor_str) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_str, padding: false),
         {^name, _height, _txi_idx} = name_op <- :erlang.binary_to_term(cursor_bin) do
      name_op
    else
      _invalid ->
        raise(ErrInput.Cursor, value: cursor_str)
    end
  end

  defp expand_txi_idx(state, {_bi, {txi, idx}}, opts) do
    expand_txi_idx(state, {txi, idx}, opts)
  end

  defp expand_txi_idx(state, {txi, _idx}, opts) do
    cond do
      Keyword.get(opts, :expand?, false) ->
        Txs.fetch!(state, txi)

      Keyword.get(opts, :tx_hash?, false) ->
        Enc.encode(:tx_hash, Txs.txi_to_hash(state, txi))

      true ->
        txi
    end
  end

  defp paginate_nested_resource(
         state,
         table,
         plain_name,
         nested_height,
         scope,
         cursor,
         pagination
       ) do
    key_boundary =
      case scope do
        nil ->
          {
            {plain_name, nested_height, {@min_int, @min_int}},
            {plain_name, nested_height, {@max_int, @max_int}}
          }

        {:gen, first_gen..last_gen} ->
          {
            {plain_name, nested_height, {DbUtil.first_gen_to_txi(state, first_gen), @min_int}},
            {plain_name, nested_height, {DbUtil.last_gen_to_txi(state, last_gen), @max_int}}
          }
      end

    cursor =
      case deserialize_nested_cursor(cursor) do
        nil -> nil
        txi_idx -> {plain_name, nested_height, txi_idx}
      end

    {prev_cursor, bi_txi_idxs, next_cursor} =
      fn direction ->
        state
        |> Collection.stream(table, direction, key_boundary, cursor)
        |> Stream.map(fn {_plain_name, _height, txi_idx} -> txi_idx end)
      end
      |> Collection.paginate(pagination)

    {serialize_nested_cursor(prev_cursor), bi_txi_idxs, serialize_nested_cursor(next_cursor)}
  end

  defp render_previous(state, name, last_gen, last_micro_time, opts) do
    name
    |> Stream.unfold(fn
      Model.name(previous: nil) -> nil
      Model.name(previous: previous) -> {previous, previous}
    end)
    |> Enum.map(&render_name_info(state, &1, last_gen, last_micro_time, opts))
  end

  defp render_claim(state, {txi, _idx} = txi_idx) do
    {claim_aetx, :name_claim_tx, tx_hash, tx_type, block_hash} =
      DbUtil.read_node_tx_details(state, txi_idx)

    Model.tx(block_index: {height, _mbi}) = State.fetch!(state, Model.Tx, txi)

    %{
      height: height,
      block_hash: Enc.encode(:micro_block_hash, block_hash),
      source_tx_hash: Enc.encode(:tx_hash, tx_hash),
      source_tx_type: Format.type_to_swagger_name(tx_type),
      internal_source: tx_type != :name_claim_tx,
      tx: :aens_claim_tx.for_client(claim_aetx)
    }
  end

  defp render_update(state, {txi, _idx} = txi_idx) do
    {update_aetx, :name_update_tx, tx_hash, tx_type, block_hash} =
      DbUtil.read_node_tx_details(state, txi_idx)

    Model.tx(block_index: {height, _mbi}) = State.fetch!(state, Model.Tx, txi)

    %{
      height: height,
      block_hash: Enc.encode(:micro_block_hash, block_hash),
      source_tx_hash: Enc.encode(:tx_hash, tx_hash),
      source_tx_type: Format.type_to_swagger_name(tx_type),
      internal_source: tx_type != :name_update_tx,
      tx: :aens_update_tx.for_client(update_aetx)
    }
  end

  defp render_transfer(state, {txi, _idx} = txi_idx) do
    {transfer_aetx, :name_transfer_tx, tx_hash, tx_type, block_hash} =
      DbUtil.read_node_tx_details(state, txi_idx)

    Model.tx(block_index: {height, _mbi}) = State.fetch!(state, Model.Tx, txi)

    %{
      height: height,
      block_hash: Enc.encode(:micro_block_hash, block_hash),
      source_tx_hash: Enc.encode(:tx_hash, tx_hash),
      source_tx_type: Format.type_to_swagger_name(tx_type),
      internal_source: tx_type != :name_transfer_tx,
      tx: :aens_transfer_tx.for_client(transfer_aetx)
    }
  end

  defp render_nested_resource(state, {{_active, {txi, _idx} = txi_idx}, table}) do
    {inner_type, tx_mod} =
      case table do
        Model.NameClaim -> {:name_claim_tx, :aens_claim_tx}
        Model.NameRevoke -> {:name_revoke_tx, :aens_revoke_tx}
        Model.NameUpdate -> {:name_update_tx, :aens_update_tx}
        Model.NameTransfer -> {:name_transfer_tx, :aens_transfer_tx}
      end

    {aetx, ^inner_type, tx_hash, tx_type, block_hash} =
      DbUtil.read_node_tx_details(state, txi_idx)

    Model.tx(block_index: {height, _mbi}) = State.fetch!(state, Model.Tx, txi)

    %{
      height: height,
      block_hash: Enc.encode(:micro_block_hash, block_hash),
      source_tx_hash: Enc.encode(:tx_hash, tx_hash),
      source_tx_type: Format.type_to_swagger_name(tx_type),
      internal_source: tx_type != inner_type,
      tx: tx_mod.for_client(aetx)
    }
  end

  defp serialize_owner_deactivation_key_boundary(owner_pk, nil),
    do: {{owner_pk, @min_int, @min_bin}, {owner_pk, @max_int, @max_bin}}

  defp serialize_owner_deactivation_key_boundary(
         owner_pk,
         {{first_gen, first_plain_name}, {last_gen, last_plain_name}}
       ),
       do: {
         {owner_pk, first_gen, first_plain_name},
         {owner_pk, last_gen, last_plain_name}
       }

  defp serialize_owner_deactivation_cursor(_owner_pk, nil), do: nil

  defp serialize_owner_deactivation_cursor(owner_pk, {gen, name}), do: {owner_pk, gen, name}

  defp deserialize_scope({:gen, first_gen..last_gen}) do
    {{first_gen, Util.min_bin()}, {last_gen, Util.max_256bit_bin()}}
  end

  defp deserialize_scope(_nil_or_txis_scope), do: nil

  defp convert_param({"owned_by", account_id}) when is_binary(account_id),
    do: {:owned_by, Validate.id!(account_id, [:account_pubkey])}

  defp convert_param({"state", state}) when state in @states, do: {:state, state}

  defp convert_param({"by", by}), do: {:by, by}

  defp convert_param(other_param),
    do: raise(ErrInput.Query, value: other_param)

  defp locate_name_or_auction(state, plain_name_or_hash) do
    plain_name =
      case State.get(state, Model.PlainName, plain_name_or_hash) do
        {:ok, Model.plain_name(value: plain_name)} -> plain_name
        :not_found -> plain_name_or_hash
      end

    case Name.locate(state, plain_name) do
      {name_or_auction, _source} -> {:ok, name_or_auction}
      nil -> {:error, ErrInput.NotFound.exception(value: plain_name_or_hash)}
    end
  end

  defp serialize_nested_cursor(nil), do: nil

  defp serialize_nested_cursor({{txi, idx}, is_reverse?}), do: {"#{txi}-#{idx + 1}", is_reverse?}

  defp deserialize_nested_cursor(nil), do: nil

  defp deserialize_nested_cursor(cursor_bin) do
    case Regex.run(~r/\A(\d+)-(\d+)\z/, cursor_bin, capture: :all_but_first) do
      [txi, idx] -> {String.to_integer(txi), String.to_integer(idx) - 1}
      _error_or_invalid -> nil
    end
  end
end

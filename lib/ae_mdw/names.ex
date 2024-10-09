defmodule AeMdw.Names do
  @moduledoc """
  Context module for dealing with Names.
  """

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
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Util
  alias AeMdw.Validate

  require Model

  @type cursor() :: binary() | nil
  @type page_cursor() :: Collection.pagination_cursor()
  @type reason :: ErrInput.t()
  # This needs to be an actual type like AeMdw.Db.Name.t()
  @type name :: term()
  @type history_item :: claim() | update() | transfer() | revoke()
  @type claim() :: map()
  @type update() :: map()
  @type transfer() :: map()
  @type revoke() :: map()
  @type pointee() :: map()
  @type plain_name() :: String.t()
  @type name_hash() :: binary()
  @type name_fee() :: non_neg_integer()
  @type auction_timeout :: non_neg_integer()
  @type ttl :: non_neg_integer()
  @type pointer :: term()
  @type pointers :: [pointer()]
  @type raw_data_pointer :: {:data, binary()}
  @type query :: %{binary() => binary()}

  @typep state() :: State.t()
  @typep order_by :: :expiration | :name
  @typep pagination :: Collection.direction_limit()
  @typep range :: {:gen, Range.t()} | nil
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
  @table_pointees Model.Pointee

  @states ~w(active inactive)
  @all_lifecycles ~w(active inactive auction)a

  @min_int Util.min_int()
  @max_int Util.max_int()
  @min_bin Util.min_bin()
  @max_bin Util.max_256bit_bin()

  @spec count_names(state(), query()) :: {:ok, non_neg_integer()} | {:error, reason()}
  def count_names(state, query) do
    with {:ok, query_params} <- Util.convert_params(query, &convert_param/1) do
      {:ok, count_active_names(state, Map.get(query_params, :owned_by))}
    end
  end

  @spec fetch_names(state(), pagination(), range(), order_by(), query(), cursor() | nil, opts()) ::
          {:ok, {page_cursor(), [name()], page_cursor()}} | {:error, reason()}
  def fetch_names(state, pagination, range, order_by, query, cursor, opts)
      when order_by in [:activation, :expiration, :deactivation] do
    cursor = deserialize_height_cursor(cursor)
    scope = deserialize_scope(range)

    with {:ok, filters} <- Util.convert_params(query, &convert_param/1),
         :ok <- validate_height_filters(filters, order_by) do
      last_micro_time = DbUtil.last_gen_and_time(state)

      paginated_names =
        filters
        |> build_height_streamer(state, order_by, scope, cursor)
        |> Collection.paginate(
          pagination,
          &render_exp_height_name(state, &1, last_micro_time, opts),
          &serialize_height_cursor/1
        )

      {:ok, paginated_names}
    end
  end

  def fetch_names(state, pagination, nil, :name, query, cursor, opts) do
    cursor = deserialize_name_cursor(cursor)

    with {:ok, filters} <- Util.convert_params(query, &convert_param/1),
         :ok <- validate_name_filters(filters) do
      last_micro_time = DbUtil.last_gen_and_time(state)

      paginated_names =
        filters
        |> build_name_streamer(state, cursor)
        |> Collection.paginate(
          pagination,
          &render_plain_name(state, &1, last_micro_time, opts),
          &serialize_name_cursor/1
        )

      {:ok, paginated_names}
    end
  end

  def fetch_names(_state, _pagination, _range, :name, _query, _cursor, _opts) do
    {:error, ErrInput.Query.exception(value: "can't scope names sorted by name")}
  end

  @spec fetch_name(state(), plain_name() | name_hash(), opts()) ::
          {:ok, name()} | {:error, Error.t()}
  def fetch_name(state, plain_name_or_hash, opts) do
    case locate_name_or_auction_source(state, plain_name_or_hash) do
      {:ok, _auction_bid, Model.AuctionBid} ->
        {:error, ErrInput.NotFound.exception(value: plain_name_or_hash)}

      {:ok, Model.name(index: plain_name), source} ->
        last_micro_time = DbUtil.last_gen_and_time(state)

        {:ok, render_plain_name(state, {plain_name, source}, last_micro_time, opts)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec fetch_name_history(state(), pagination(), plain_name(), cursor()) ::
          {:ok, {page_cursor(), [history_item()], page_cursor()}} | {:error, reason()}
  def fetch_name_history(state, pagination, plain_name_or_hash, cursor) do
    with {:ok, name_or_auction} <- locate_name_or_auction(state, plain_name_or_hash),
         plain_name <- get_index(name_or_auction),
         {:ok, cursor} <- deserialize_history_cursor(plain_name, cursor) do
      paginated_history =
        state
        |> build_history_streamer(plain_name, cursor)
        |> Collection.paginate(
          pagination,
          &render_nested_resource(state, &1),
          &serialize_history_cursor(plain_name, &1)
        )

      {:ok, paginated_history}
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

          Model.auction_bid(index: plain_name, start_height: start_height) ->
            {plain_name, Model.AuctionBidClaim, start_height}
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

      {:ok, {prev_cursor, Enum.map(claims, &render_nested_resource(state, &1)), next_cursor}}
    end
  end

  @spec fetch_auction_claims(state(), binary(), pagination(), range(), cursor() | nil) ::
          {:ok, {page_cursor(), [claim()], page_cursor()}} | {:error, Error.t()}
  def fetch_auction_claims(state, plain_name_or_hash, pagination, scope, cursor) do
    case locate_name_or_auction(state, plain_name_or_hash) do
      {:ok, Model.auction_bid(index: plain_name, start_height: start_height)} ->
        {prev_cursor, claims, next_cursor} =
          paginate_nested_resource(
            state,
            Model.AuctionBidClaim,
            plain_name,
            start_height,
            scope,
            cursor,
            pagination
          )

        {:ok, {prev_cursor, Enum.map(claims, &render_nested_resource(state, &1)), next_cursor}}

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

        {:ok, {prev_cursor, Enum.map(updates, &render_nested_resource(state, &1)), next_cursor}}

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

        {:ok, {prev_cursor, Enum.map(updates, &render_nested_resource(state, &1)), next_cursor}}

      {:ok, Model.auction_bid()} ->
        {:error, ErrInput.NotFound.exception(value: plain_name_or_hash)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec fetch_pointees(state(), binary(), pagination(), range(), cursor()) ::
          {:ok, {page_cursor(), [pointee()], page_cursor()}} | {:error, reason()}
  def fetch_pointees(state, account_id, pagination, scope, cursor) do
    with {:ok, account_pk} <- Validate.id(account_id),
         {:ok, cursor} <- deserialize_pointees_cursor(account_pk, cursor) do
      scope =
        case scope do
          nil ->
            {
              {account_pk, {{@min_int, -1}, {-1, -1}}, <<>>},
              {account_pk, {{@max_int, -1}, {-1, -1}}, <<>>}
            }

          {:gen, gen_start..gen_end//_step} ->
            {
              {account_pk, {{gen_start, @min_int}, {-1, -1}}, <<>>},
              {account_pk, {{gen_end, @max_int}, {-1, -1}}, <<>>}
            }
        end

      paginated_pointees =
        (&Collection.stream(state, @table_pointees, &1, scope, cursor))
        |> Collection.paginate(
          pagination,
          &render_pointee(state, &1),
          &serialize_pointees_cursor/1
        )

      {:ok, paginated_pointees}
    end
  end

  @spec expire_after(Blocks.height()) :: Blocks.height()
  def expire_after(auction_end) do
    auction_end + :aec_governance.name_claim_max_expiration(Db.proto_vsn(auction_end))
  end

  @spec increment_names_count(state(), Db.pubkey()) :: State.t()
  def increment_names_count(state, owner_pk) do
    State.update(
      state,
      Model.AccountNamesCount,
      owner_pk,
      fn
        nil ->
          Model.account_names_count(index: owner_pk, count: 1)

        Model.account_names_count(index: owner_pk, count: count) ->
          Model.account_names_count(index: owner_pk, count: count + 1)
      end
    )
  end

  @spec decrement_names_count(state(), Db.pubkey()) :: State.t()
  def decrement_names_count(state, owner_pk) do
    State.update(
      state,
      Model.AccountNamesCount,
      owner_pk,
      fn
        Model.account_names_count(index: owner_pk, count: 0) ->
          Model.account_names_count(index: owner_pk, count: 0)

        Model.account_names_count(index: owner_pk, count: count) ->
          Model.account_names_count(index: owner_pk, count: count - 1)
      end,
      Model.account_names_count(index: owner_pk, count: 0)
    )
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

  defp build_name_streamer(%{state: "inactive"} = filters, state, cursor) do
    prefix = Map.get(filters, :prefix, "")
    scope = {prefix, prefix <> Util.max_256bit_bin()}

    fn direction ->
      state
      |> Collection.stream(@table_inactive, direction, scope, cursor)
      |> Stream.map(fn key -> {key, :inactive} end)
    end
  end

  defp build_name_streamer(%{state: "active"} = filters, state, cursor) do
    prefix = Map.get(filters, :prefix, "")
    scope = {prefix, prefix <> Util.max_256bit_bin()}

    fn direction ->
      state
      |> Collection.stream(@table_active, direction, scope, cursor)
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

  defp build_name_streamer(filters, state, cursor) do
    prefix = Map.get(filters, :prefix, "")
    scope = {prefix, prefix <> Util.max_256bit_bin()}

    fn direction ->
      active_stream =
        state
        |> Collection.stream(@table_active, direction, scope, cursor)
        |> Stream.map(fn key -> {key, :active} end)

      inactive_stream =
        state
        |> Collection.stream(@table_inactive, direction, scope, cursor)
        |> Stream.map(fn key -> {key, :inactive} end)

      Collection.merge([active_stream, inactive_stream], direction)
    end
  end

  defp build_height_streamer(
         %{owned_by: owner_pk, state: "active"},
         state,
         _order_by,
         scope,
         cursor
       ) do
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

  defp build_height_streamer(
         %{owned_by: owner_pk, state: "inactive"},
         state,
         _order_by,
         scope,
         cursor
       ) do
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

  defp build_height_streamer(%{owned_by: owner_pk}, state, _order_by, scope, cursor) do
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

  defp build_height_streamer(%{state: "active"}, state, :activation, scope, cursor) do
    fn direction ->
      state
      |> Collection.stream(@table_activation, direction, scope, cursor)
      |> Stream.map(&{&1, :active})
    end
  end

  defp build_height_streamer(%{state: "active"}, state, _order_by, scope, cursor) do
    fn direction ->
      state
      |> Collection.stream(@table_active_expiration, direction, scope, cursor)
      |> Stream.map(&{&1, :active})
    end
  end

  defp build_height_streamer(%{state: "inactive"}, state, _order_by, scope, cursor) do
    fn direction ->
      state
      |> Collection.stream(@table_inactive_expiration, direction, scope, cursor)
      |> Stream.map(&{&1, :inactive})
    end
  end

  defp build_height_streamer(_query, state, _order_by, scope, cursor) do
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
      [
        Model.AuctionBidClaim,
        Model.NameClaim,
        Model.NameUpdate,
        Model.NameTransfer,
        Model.NameRevoke,
        Model.NameExpired
      ]
      |> Enum.map(fn table ->
        Name.stream_nested_resource(state, table, direction, plain_name, cursor)
      end)
      |> Collection.merge(direction)
    end
  end

  @spec fetch_active_names(state(), pagination(), range(), order_by(), cursor(), opts()) ::
          {:ok, {page_cursor(), [name()], page_cursor()}} | {:error, reason()}
  def fetch_active_names(state, pagination, range, order_by, cursor, opts),
    do: fetch_names(state, pagination, range, order_by, %{"state" => "active"}, cursor, opts)

  @spec search_names(state(), [lifecycle()], prefix(), pagination(), cursor(), opts()) ::
          {page_cursor(), [name()], page_cursor()}

  def search_names(state, [], prefix, pagination, cursor, opts),
    do: search_names(state, @all_lifecycles, prefix, pagination, cursor, opts)

  def search_names(state, lifecycles, prefix, pagination, cursor, opts) do
    cursor = deserialize_name_cursor(cursor)
    scope = {prefix, prefix <> Util.max_256bit_bin()}
    last_micro_time = DbUtil.last_gen_and_time(state)

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
    |> Collection.paginate(
      pagination,
      &render_search(state, &1, last_micro_time, opts),
      &serialize_name_cursor/1
    )
  end

  @spec fetch_previous_list(state(), plain_name()) :: [name()]
  def fetch_previous_list(state, plain_name) do
    {last_gen, last_micro_time} = DbUtil.last_gen_and_time(state)
    key_boundary = {{plain_name, @min_int}, {plain_name, @max_int}}

    state
    |> Collection.stream(Model.PreviousName, :backward, key_boundary, nil)
    |> Enum.map(fn previous_index ->
      Model.previous_name(name: name) = State.fetch!(state, Model.PreviousName, previous_index)
      render_name_info(state, name, last_gen, last_micro_time, [])
    end)
  end

  @spec revoke_or_expire_height(Model.name()) :: Blocks.height()
  def revoke_or_expire_height(m_name) do
    case {Model.name(m_name, :revoke), Model.name(m_name, :expire)} do
      {nil, expire} -> expire
      {{{revoke_height, _revoke_mbi}, _revoke_txi}, _expire} -> revoke_height
    end
  end

  defp render_exp_height_name(state, {{_exp, plain_name}, source}, last_micro_time, opts),
    do: render(state, plain_name, source == :active, last_micro_time, opts)

  defp render_plain_name(state, {plain_name, source}, last_micro_time, opts),
    do:
      render(
        state,
        plain_name,
        source == :active || source == Model.ActiveName,
        last_micro_time,
        opts
      )

  defp render_search(state, {plain_name, :auction}, _last_micro_time, opts) do
    %{"type" => "auction", "payload" => AuctionBids.fetch!(state, plain_name, opts)}
  end

  defp render_search(state, {plain_name, source}, last_micro_time, opts) do
    %{
      "type" => "name",
      "payload" => render(state, plain_name, source == :active, last_micro_time, opts)
    }
  end

  defp render(state, plain_name, is_active?, last_micro_time, opts) do
    if Keyword.get(opts, :render_v3?, false) do
      render_v3(state, plain_name, is_active?, last_micro_time, opts)
    else
      render_v2(state, plain_name, is_active?, last_micro_time, opts)
    end
  end

  defp render_v3(state, plain_name, is_active?, {last_gen, last_micro_time}, opts) do
    Model.name(
      active: active,
      expire: expire,
      revoke: revoke,
      auction_timeout: auction_timeout,
      claims_count: claims_count
    ) =
      name =
      State.fetch!(state, if(is_active?, do: @table_active, else: @table_inactive), plain_name)

    protocol = :aec_hard_forks.protocol_effective_at_height(last_gen)

    opts = [{:v3?, true} | opts]

    name_hash =
      case :aens.get_name_hash(plain_name) do
        {:ok, name_id_bin} -> Enc.encode(:name, name_id_bin)
        _error -> nil
      end

    {auction_bid, claims_count} =
      case AuctionBids.fetch(state, plain_name, opts) do
        {:ok, auction_bid} ->
          {_version, %{claims_count: claims_count} = auction_bid} =
            pop_in(auction_bid, [:last_bid, "tx", "version"])

          {auction_bid, claims_count}

        :not_found ->
          {nil, claims_count}
      end

    %{
      name: plain_name,
      hash: name_hash,
      auction: auction_bid,
      active: is_active?,
      active_from: active,
      approximate_activation_time:
        DbUtil.height_to_time(state, active, last_gen, last_micro_time),
      expire_height: expire,
      approximate_expire_time: DbUtil.height_to_time(state, expire, last_gen, last_micro_time),
      name_fee: :aec_governance.name_claim_fee(plain_name, protocol),
      revoke: revoke && expand_txi_idx(state, revoke, opts),
      auction_timeout: auction_timeout,
      pointers: Name.pointers_v3(state, name),
      ownership: render_ownership(state, name),
      claims_count: claims_count
    }
  end

  defp render_v2(state, plain_name, is_active?, {last_gen, last_micro_time}, opts) do
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
      previous: render_previous(state, plain_name, last_gen, last_micro_time, opts)
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

  defp render_ownership(state, name) do
    %{current: current_owner, original: original_owner} = Name.ownership(state, name)

    %{
      current: Format.enc_id(current_owner),
      original: Format.enc_id(original_owner)
    }
  end

  defp serialize_name_cursor({name, _tab}), do: serialize_name_cursor(name)

  defp serialize_name_cursor(name), do: name

  defp deserialize_name_cursor(nil), do: nil

  defp deserialize_name_cursor(cursor_bin) do
    if Regex.match?(~r/\A[-\w\.]+\z/, cursor_bin) do
      cursor_bin
    else
      nil
    end
  end

  defp serialize_height_cursor({{height, name}, _tab}),
    do: serialize_height_cursor({height, name})

  defp serialize_height_cursor({height, name}),
    do: Base.encode64(:erlang.term_to_binary({height, name}), padding: false)

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

  defp serialize_history_cursor(name, {height, txi_idx, _table}) do
    {name, height, txi_idx}
    |> :erlang.term_to_binary()
    |> Base.encode64(padding: false)
  end

  defp deserialize_history_cursor(_name, nil), do: {:ok, nil}

  defp deserialize_history_cursor(name, cursor_str) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_str, padding: false),
         {^name, _height, _txi_idx} = name_op <- :erlang.binary_to_term(cursor_bin) do
      {:ok, name_op}
    else
      _invalid ->
        {:error, ErrInput.Cursor.exception(value: cursor_str)}
    end
  end

  defp expand_txi_idx(state, {_bi, {txi, idx}}, opts) do
    expand_txi_idx(state, {txi, idx}, opts)
  end

  defp expand_txi_idx(state, {txi, _idx}, opts) do
    cond do
      Keyword.get(opts, :v3?, false) ->
        state
        |> Txs.fetch!(txi, opts)
        |> Map.put("tx_hash", Enc.encode(:tx_hash, Txs.txi_to_hash(state, txi)))
        |> Map.drop(["tx_index"])

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

        {:gen, first_gen..last_gen//_step} ->
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

    fn direction ->
      state
      |> Collection.stream(table, direction, key_boundary, cursor)
      |> Stream.map(fn {_plain_name, height, txi_idx} -> {height, txi_idx, table} end)
    end
    |> Collection.paginate(pagination, & &1, &serialize_nested_cursor/1)
  end

  defp render_previous(state, plain_name, last_gen, last_micro_time, opts) do
    key_boundary = {{plain_name, @min_int}, {plain_name, @max_int}}

    state
    |> Collection.stream(Model.PreviousName, :backward, key_boundary, nil)
    |> Stream.map(&State.fetch!(state, Model.PreviousName, &1))
    |> Enum.map(fn Model.previous_name(name: name) ->
      render_name_info(state, name, last_gen, last_micro_time, opts)
    end)
  end

  defp render_nested_resource(_state, {active_from, {nil, height}, Model.NameExpired}) do
    %{
      active_from: active_from,
      expired_at: height
    }
  end

  defp render_nested_resource(state, {active_from, {txi, _idx} = txi_idx, table}) do
    tx_type =
      case table do
        Model.AuctionBidClaim -> :name_claim_tx
        Model.NameClaim -> :name_claim_tx
        Model.NameRevoke -> :name_revoke_tx
        Model.NameUpdate -> :name_update_tx
        Model.NameTransfer -> :name_transfer_tx
      end

    {tx_rec, ^tx_type, tx_hash, chain_tx_type, block_hash} =
      DbUtil.read_node_tx_details(state, txi_idx)

    Model.tx(block_index: {height, _mbi}) = State.fetch!(state, Model.Tx, txi)

    %{
      active_from: active_from,
      height: height,
      block_hash: Enc.encode(:micro_block_hash, block_hash),
      source_tx_hash: Enc.encode(:tx_hash, tx_hash),
      source_tx_type: Node.tx_name(chain_tx_type),
      internal_source: chain_tx_type != tx_type,
      tx: Node.tx_mod(tx_type).for_client(tx_rec)
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

  defp deserialize_scope({:gen, first_gen..last_gen//_step}) do
    {{first_gen, Util.min_bin()}, {last_gen, Util.max_256bit_bin()}}
  end

  defp deserialize_scope(_nil_or_txis_scope), do: nil

  defp convert_param({"owned_by", account_id}) when is_binary(account_id) do
    with {:ok, pubkey} <- Validate.id(account_id, [:account_pubkey]) do
      {:ok, {:owned_by, pubkey}}
    end
  end

  defp convert_param({"state", state}) when state in @states, do: {:ok, {:state, state}}

  defp convert_param({"prefix", prefix}) when is_binary(prefix),
    do: {:ok, {:prefix, String.downcase(prefix)}}

  defp convert_param(other_param), do: {:error, ErrInput.Query.exception(value: other_param)}

  defp get_index(Model.auction_bid(index: plain_name)), do: plain_name
  defp get_index(Model.name(index: plain_name)), do: plain_name

  defp locate_name_or_auction(state, plain_name_or_hash) do
    with {:ok, name_or_auction, _source} <-
           locate_name_or_auction_source(state, plain_name_or_hash) do
      {:ok, name_or_auction}
    end
  end

  defp locate_name_or_auction_source(state, plain_name_or_hash) do
    plain_name =
      with {:ok, hash_bin} <- Validate.name_id(plain_name_or_hash),
           {:ok, Model.plain_name(value: plain_name)} <-
             State.get(state, Model.PlainName, hash_bin) do
        plain_name
      else
        _no_hash -> plain_name_or_hash
      end

    case Name.locate(state, plain_name) do
      {name_or_auction, source} -> {:ok, name_or_auction, source}
      nil -> {:error, ErrInput.NotFound.exception(value: plain_name_or_hash)}
    end
  end

  defp serialize_nested_cursor({_height, {txi, idx}, _table}), do: "#{txi}-#{idx + 1}"

  defp deserialize_nested_cursor(nil), do: nil

  defp deserialize_nested_cursor(cursor_bin) do
    case Regex.run(~r/\A(\d+)-(\d+)\z/, cursor_bin, capture: :all_but_first) do
      [txi, idx] -> {String.to_integer(txi), String.to_integer(idx) - 1}
      _error_or_invalid -> nil
    end
  end

  defp validate_height_filters(filters, :activation) do
    case Map.get(filters, :state) do
      "active" ->
        :ok

      _state ->
        {:error,
         ErrInput.Query.exception(
           value: "can only order by activation when filtering active names"
         )}
    end
  end

  defp validate_height_filters(%{prefix: _prefix}, _order_by),
    do:
      {:error,
       ErrInput.Query.exception(
         value: "can't filter by prefix when ordering by activation, deactivation or expiration"
       )}

  defp validate_height_filters(_filters, _order_by), do: :ok

  defp validate_name_filters(%{prefix: _prefix, owned_by: _owner_pk}),
    do: {:error, ErrInput.Query.exception(value: "can't filter by owner and prefix")}

  defp validate_name_filters(_filters), do: :ok

  defp deserialize_pointees_cursor(_account_pk, nil), do: {:ok, nil}

  defp deserialize_pointees_cursor(account_pk, cursor_bin) do
    with [height_bin, mbi_bin, txi_bin, idx_bin, pointee_key_bin] <-
           Regex.run(~r/\A(\d+)-(\d+)-(\d+)-(\d+)-(\w+)\z/, cursor_bin, capture: :all_but_first),
         {:ok, pointee_key} <- Base.decode64(pointee_key_bin, padding: false) do
      mbi = String.to_integer(mbi_bin)
      height = String.to_integer(height_bin)
      txi = String.to_integer(txi_bin)
      idx = String.to_integer(idx_bin) - 1

      {:ok, {account_pk, {{height, mbi}, {txi, idx}}, pointee_key}}
    else
      _invalid_cursor ->
        {:error, ErrInput.Cursor.exception(value: cursor_bin)}
    end
  end

  defp serialize_pointees_cursor({_account_pk, {{height, mbi}, {txi, idx}}, pointee_key}) do
    pointee_base64 = Base.encode64(pointee_key, padding: false)

    "#{height}-#{mbi}-#{txi}-#{idx + 1}-#{pointee_base64}"
  end

  defp render_pointee(state, {_account_pk, {{height, _mbi}, txi_idx}, pointee_key}) do
    {name_update_tx, :name_update_tx, tx_hash, tx_type, block_hash} =
      DbUtil.read_node_tx_details(state, txi_idx)

    name_hash = :aens_update_tx.name_hash(name_update_tx)
    plain_name = Name.plain_name!(state, name_hash)
    block_time = Db.get_block_time(block_hash)

    %{
      name: plain_name,
      active: State.exists?(state, Model.ActiveName, plain_name),
      key: pointee_key,
      block_height: height,
      block_hash: Enc.encode(:micro_block_hash, block_hash),
      block_time: block_time,
      source_tx_hash: Enc.encode(:tx_hash, tx_hash),
      source_tx_type: Node.tx_name(tx_type),
      tx: :aens_update_tx.for_client(name_update_tx)
    }
  end

  defp count_active_names(state, nil) do
    case State.prev(state, Model.TotalStat, nil) do
      {:ok, index} ->
        Model.total_stat(active_names: count) = State.fetch!(state, Model.TotalStat, index)

        count

      :none ->
        0
    end
  end

  defp count_active_names(state, owned_by) do
    state
    |> State.get(Model.AccountNamesCount, owned_by)
    |> case do
      {:ok, Model.account_names_count(count: count)} -> count
      :not_found -> 0
    end
  end
end

defmodule AeMdw.Names do
  @moduledoc """
  Context module for dealing with Names.
  """

  require AeMdw.Db.Model

  alias :aeser_api_encoder, as: Enc

  alias AeMdw.AuctionBids
  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Contracts
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.State
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Util
  alias AeMdw.Validate

  @type cursor :: binary()
  # This needs to be an actual type like AeMdw.Db.Name.t()
  @type name :: term()
  @type claim() :: map()
  @type update() :: map()
  @type transfer() :: map()
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
          {:ok, cursor() | nil, [name()], cursor() | nil} | {:error, reason()}
  def fetch_names(state, pagination, range, order_by, query, cursor, opts)
      when order_by in [:activation, :expiration, :deactivation] do
    cursor = deserialize_height_cursor(cursor)
    scope = deserialize_scope(range)

    try do
      {prev_cursor, height_keys, next_cursor} =
        query
        |> Map.drop(@pagination_params)
        |> Enum.into(%{}, &convert_param/1)
        |> build_height_streamer(state, scope, cursor)
        |> Collection.paginate(pagination)

      {:ok, serialize_height_cursor(prev_cursor), render_height_list(state, height_keys, opts),
       serialize_height_cursor(next_cursor)}
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
        |> Enum.into(%{}, &convert_param/1)
        |> build_name_streamer(state, cursor)
        |> Collection.paginate(pagination)

      {:ok, serialize_name_cursor(prev_cursor), render_names_list(state, name_keys, opts),
       serialize_name_cursor(next_cursor)}
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

  @spec fetch_name_claims(state(), binary(), pagination(), range(), nested_cursor() | nil) ::
          {:ok, {nested_cursor() | nil, [claim()], nested_cursor() | nil}} | {:error, Error.t()}
  def fetch_name_claims(state, plain_name_or_hash, pagination, scope, cursor) do
    with {:ok, name_or_auction} <- locate_name_or_auction(state, plain_name_or_hash) do
      {claims, plain_name} =
        case name_or_auction do
          Model.name(index: plain_name, claims: claims) -> {claims, plain_name}
          Model.auction_bid(index: plain_name, bids: bids) -> {bids, plain_name}
        end

      {prev_cursor, claims, next_cursor} =
        paginate_nested_resource(claims, scope, cursor, pagination)

      {:ok, {prev_cursor, Enum.map(claims, &render_claim(state, plain_name, &1)), next_cursor}}
    end
  end

  @spec fetch_name_updates(state(), binary(), pagination(), range(), nested_cursor() | nil) ::
          {:ok, {nested_cursor() | nil, [update()], nested_cursor() | nil}} | {:error, Error.t()}
  def fetch_name_updates(state, plain_name_or_hash, pagination, scope, cursor) do
    with {:ok, name_or_auction} <- locate_name_or_auction(state, plain_name_or_hash) do
      {updates, plain_name} =
        case name_or_auction do
          Model.name(index: plain_name, updates: updates) -> {updates, plain_name}
          Model.auction_bid(index: plain_name) -> {[], plain_name}
        end

      {prev_cursor, updates, next_cursor} =
        paginate_nested_resource(updates, scope, cursor, pagination)

      {:ok, {prev_cursor, Enum.map(updates, &render_update(state, plain_name, &1)), next_cursor}}
    end
  end

  @spec fetch_name_transfers(state(), binary(), pagination(), range(), nested_cursor() | nil) ::
          {:ok, {nested_cursor() | nil, [update()], nested_cursor() | nil}} | {:error, Error.t()}
  def fetch_name_transfers(state, plain_name_or_hash, pagination, scope, cursor) do
    with {:ok, name_or_auction} <- locate_name_or_auction(state, plain_name_or_hash) do
      {transfers, plain_name} =
        case name_or_auction do
          Model.name(index: plain_name, transfers: transfers) -> {transfers, plain_name}
          Model.auction_bid(index: plain_name) -> {[], plain_name}
        end

      {prev_cursor, transfers, next_cursor} =
        paginate_nested_resource(transfers, scope, cursor, pagination)

      {:ok,
       {prev_cursor, Enum.map(transfers, &render_transfer(state, plain_name, &1)), next_cursor}}
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

  @spec fetch_active_names(state(), pagination(), range(), order_by(), cursor() | nil, opts()) ::
          {:ok, cursor() | nil, [name()], cursor() | nil} | {:error, reason()}
  def fetch_active_names(state, pagination, range, order_by, cursor, opts),
    do: fetch_names(state, pagination, range, order_by, %{"state" => "active"}, cursor, opts)

  @spec fetch_inactive_names(state(), pagination(), range(), order_by(), cursor() | nil, opts()) ::
          {:ok, cursor() | nil, [name()], cursor() | nil} | {:error, reason()}
  def fetch_inactive_names(state, pagination, range, order_by, cursor, opts),
    do: fetch_names(state, pagination, range, order_by, %{"state" => "inactive"}, cursor, opts)

  @spec search_names(state(), [lifecycle()], prefix(), pagination(), cursor() | nil, opts()) ::
          {cursor() | nil, [name()], cursor() | nil}

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
    case State.get(state, @table_inactive, plain_name) do
      {:ok, name} ->
        name
        |> Stream.unfold(fn
          nil ->
            nil

          Model.name(previous: previous) = name ->
            {render_name_info(state, name, []), previous}
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
    Enum.map(names_tables_keys, fn {{_exp, plain_name}, source} ->
      render(state, plain_name, source == :active, opts)
    end)
  end

  defp render_names_list(state, names_tables_keys, opts) do
    Enum.map(names_tables_keys, fn {plain_name, source} ->
      render(state, plain_name, source == :active, opts)
    end)
  end

  defp render_search_list(state, names_tables_keys, opts) do
    Enum.map(names_tables_keys, fn
      {plain_name, :auction} ->
        %{"type" => "auction", "payload" => AuctionBids.fetch!(state, plain_name, opts)}

      {plain_name, source} ->
        %{"type" => "name", "payload" => render(state, plain_name, source == :active, opts)}
    end)
  end

  defp render(state, plain_name, is_active?, opts) do
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
      info: render_name_info(state, name, opts),
      previous: render_previous(state, name, opts)
    }
  end

  defp render_name_info(
         state,
         Model.name(
           active: active,
           expire: expire,
           claims: claims,
           updates: updates,
           transfers: transfers,
           revoke: revoke,
           auction_timeout: auction_timeout
         ) = name,
         opts
       ) do
    %{
      active_from: active,
      expire_height: expire,
      claims: Enum.map(claims, &expand_txi(state, &1, opts)),
      updates: Enum.map(updates, &expand_txi(state, &1, opts)),
      transfers: Enum.map(transfers, &expand_txi(state, &1, opts)),
      revoke: (revoke && expand_txi(state, revoke, opts)) || nil,
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

  defp serialize_height_cursor(nil), do: nil

  defp serialize_height_cursor({{{height, name}, _tab}, is_reversed?}),
    do: serialize_height_cursor({{height, name}, is_reversed?})

  defp serialize_height_cursor({{height, name}, is_reversed?}),
    do: {"#{height}-#{name}", is_reversed?}

  defp deserialize_height_cursor(nil), do: nil

  defp deserialize_height_cursor(cursor_bin) do
    case Regex.run(~r/\A(\d+)-([\w\.]+)\z/, cursor_bin) do
      [_match0, exp_height, name] -> {String.to_integer(exp_height), name}
      nil -> nil
    end
  end

  defp expand_txi(state, bi_txi, opts) do
    txi = Format.bi_txi_txi(bi_txi)

    cond do
      Keyword.get(opts, :expand?, false) ->
        Txs.fetch!(state, txi)

      Keyword.get(opts, :tx_hash?, false) ->
        Enc.encode(:tx_hash, Txs.txi_to_hash(state, txi))

      true ->
        txi
    end
  end

  defp paginate_nested_resource(bi_txis, scope, cursor, pagination) do
    cursor = deserialize_nested_cursor(cursor)

    bi_txis =
      case scope do
        {:gen, first_gen..last_gen} ->
          bi_txis
          |> Enum.drop_while(fn {{height, _mbi}, _txi} -> height >= last_gen end)
          |> Enum.take_while(fn {{height, _mbi}, _txi} -> height <= first_gen end)

        nil ->
          bi_txis
      end

    streamer = fn
      :forward ->
        bi_txis = Enum.reverse(bi_txis)

        if cursor do
          Enum.drop_while(bi_txis, &(&1 < cursor))
        else
          bi_txis
        end

      :backward ->
        if cursor do
          Enum.drop_while(bi_txis, &(&1 > cursor))
        else
          bi_txis
        end
    end

    {prev_cursor, bi_txis, next_cursor} = Collection.paginate(streamer, pagination)

    {serialize_nested_cursor(prev_cursor), bi_txis, serialize_nested_cursor(next_cursor)}
  end

  defp render_previous(state, name, opts) do
    name
    |> Stream.unfold(fn
      Model.name(previous: nil) -> nil
      Model.name(previous: previous) -> {previous, previous}
    end)
    |> Enum.map(&render_name_info(state, &1, opts))
  end

  defp render_claim(state, plain_name, {{height, _mbi} = block_index, txi}) do
    block_hash = Blocks.block_index_to_hash(state, block_index)

    claim_aetx =
      Contracts.get_aetx(state, txi, :name_claim_tx, "AENS.claim", fn tx ->
        :aens_claim_tx.name(tx) == plain_name
      end)

    %{
      height: height,
      block_hash: Enc.encode(:micro_block_hash, block_hash),
      tx: :aetx.serialize_for_client(claim_aetx)
    }
  end

  defp render_update(state, plain_name, {{height, _mbi} = block_index, txi}) do
    block_hash = Blocks.block_index_to_hash(state, block_index)

    update_aetx =
      Contracts.get_aetx(state, txi, :name_update_tx, "AENS.update", fn tx ->
        :aens_update_tx.name(tx) == plain_name
      end)

    %{
      height: height,
      block_hash: Enc.encode(:micro_block_hash, block_hash),
      tx: :aetx.serialize_for_client(update_aetx)
    }
  end

  defp render_transfer(state, plain_name, {{height, _mbi} = block_index, txi}) do
    block_hash = Blocks.block_index_to_hash(state, block_index)

    transfer_aetx =
      Contracts.get_aetx(state, txi, :name_transfer_tx, "AENS.transfer", fn tx ->
        :aens_transfer_tx.name(tx) == plain_name
      end)

    %{
      height: height,
      block_hash: Enc.encode(:micro_block_hash, block_hash),
      tx: :aetx.serialize_for_client(transfer_aetx)
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

  defp serialize_nested_cursor({{{height, mbi}, txi}, is_reverse?}),
    do: {"#{height}-#{mbi}-#{txi}", is_reverse?}

  defp deserialize_nested_cursor(nil), do: nil

  defp deserialize_nested_cursor(cursor_bin) do
    case Regex.run(~r/\A(\d+)-(\d+)-(\d+)\z/, cursor_bin, capture: :all_but_first) do
      [height, mbi, txi] ->
        {{String.to_integer(height), String.to_integer(mbi)}, String.to_integer(txi)}

      _error_or_invalid ->
        nil
    end
  end
end

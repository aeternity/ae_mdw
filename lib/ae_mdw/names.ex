defmodule AeMdw.Names do
  @moduledoc """
  Context module for dealing with Names.
  """

  require AeMdw.Db.Model

  alias :aeser_api_encoder, as: Enc

  alias AeMdw.AuctionBids
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.Collection
  alias AeMdw.Mnesia
  # alias AeMdw.Node
  alias AeMdw.Txs

  @type cursor :: binary()
  # This needs to be an actual type like AeMdw.Db.Name.t()
  @type name :: term()
  @type plain_name() :: binary()
  @type name_hash() :: binary()
  @type name_fee() :: non_neg_integer()
  @type auction_timeout :: non_neg_integer()

  @typep order_by :: :expiration | :name
  @typep limit :: Mnesia.limit()
  @typep direction :: Mnesia.direction()
  @typep range :: {:gen, Range.t()} | nil

  @table_active Model.ActiveName
  @table_active_expiration Model.ActiveNameExpiration
  @table_inactive Model.InactiveName
  @table_inactive_expiration Model.InactiveNameExpiration

  @spec fetch_names(direction(), range(), order_by(), cursor() | nil, limit(), boolean()) ::
          {[name()], cursor() | nil}
  def fetch_names(direction, range, :expiration, cursor, limit, expand?) do
    cursor = deserialize_expiration_cursor(cursor)
    scope = deserialize_scope(range, direction)

    active_stream =
      @table_active_expiration
      |> Collection.stream(direction, scope, cursor)
      |> Stream.map(fn key -> {key, @table_active_expiration} end)

    inactive_stream =
      @table_inactive_expiration
      |> Collection.stream(direction, scope, cursor)
      |> Stream.map(fn key -> {key, @table_inactive_expiration} end)

    stream =
      case direction do
        :forward -> Stream.concat(inactive_stream, active_stream)
        :backward -> Stream.concat(active_stream, inactive_stream)
      end

    {expiration_keys, {next_cursor, _cursor_table}} = Collection.paginate(stream, limit)

    {render_exp_list(expiration_keys, expand?), serialize_expiration_cursor(next_cursor)}
  end

  def fetch_names(direction, range, :name, cursor, limit, expand?) do
    cursor = deserialize_name_cursor(cursor)
    scope = deserialize_scope(range, direction)

    active_stream =
      @table_active
      |> Collection.stream(direction, scope, cursor)
      |> Stream.map(fn key -> {key, @table_active} end)

    inactive_stream =
      @table_inactive
      |> Collection.stream(direction, scope, cursor)
      |> Stream.map(fn key -> {key, @table_inactive} end)

    {name_keys, {next_cursor, _cursor_table}} =
      [active_stream, inactive_stream]
      |> Collection.merge(direction)
      |> Collection.paginate(limit)

    {render_names_list(name_keys, expand?), serialize_name_cursor(next_cursor)}
  end

  @spec fetch_active_names(direction(), range(), order_by(), cursor() | nil, limit(), boolean()) ::
          {[name()], cursor() | nil}
  def fetch_active_names(direction, _range, :name, cursor, limit, expand?) do
    {name_keys, next_cursor} =
      @table_active
      |> Collection.stream(direction, nil, cursor)
      |> Collection.paginate(limit)

    {render_names_list(name_keys, true, expand?), serialize_name_cursor(next_cursor)}
  end

  def fetch_active_names(direction, range, :expiration, cursor, limit, expand?) do
    scope = deserialize_scope(range, direction)

    {exp_keys, next_cursor} =
      @table_active_expiration
      |> Collection.stream(direction, scope, deserialize_expiration_cursor(cursor))
      |> Collection.paginate(limit)

    {render_exp_list(exp_keys, true, expand?), serialize_expiration_cursor(next_cursor)}
  end

  @spec fetch_inactive_names(direction(), range(), order_by(), cursor() | nil, limit(), boolean()) ::
          {[name()], cursor() | nil}
  def fetch_inactive_names(direction, _range, :name, cursor, limit, expand?) do
    {name_keys, next_cursor} =
      @table_inactive
      |> Collection.stream(direction, nil, deserialize_name_cursor(cursor))
      |> Collection.paginate(limit)

    {render_names_list(name_keys, false, expand?), serialize_name_cursor(next_cursor)}
  end

  def fetch_inactive_names(direction, range, :expiration, cursor, limit, expand?) do
    scope = deserialize_scope(range, direction)

    {exp_keys, next_cursor} =
      @table_inactive_expiration
      |> Collection.stream(direction, scope, deserialize_expiration_cursor(cursor))
      |> Collection.paginate(limit)

    {render_exp_list(exp_keys, false, expand?), serialize_expiration_cursor(next_cursor)}
  end

  @spec fetch_previous_list(plain_name()) :: [name()]
  def fetch_previous_list(plain_name) do
    case Mnesia.fetch(@table_inactive, plain_name) do
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
      render(plain_name, source == @table_active_expiration, expand?)
    end)
  end

  defp render_exp_list(names_tables_keys, is_active?, expand?) do
    Enum.map(names_tables_keys, fn {_exp, plain_name} ->
      render(plain_name, is_active?, expand?)
    end)
  end

  defp render_names_list(names_tables_keys, expand?) do
    Enum.map(names_tables_keys, fn {plain_name, source} ->
      render(plain_name, source == @table_active, expand?)
    end)
  end

  defp render_names_list(names_tables_keys, is_active?, expand?) do
    Enum.map(names_tables_keys, fn plain_name ->
      render(plain_name, is_active?, expand?)
    end)
  end

  defp render(plain_name, is_active?, expand?) do
    name = Mnesia.fetch!(if(is_active?, do: @table_active, else: @table_inactive), plain_name)

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
         ),
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
      pointers: render_pointers(updates),
      ownership: render_ownership(claims, transfers)
    }
  end

  defp render_pointers([]) do
    %{}
  end

  defp render_pointers([{_bi, txi} | _rest_updates]) do
    txi
    |> Txs.fetch!()
    |> case do
      %{"tx" => %{"pointers" => pointers}} -> pointers
      %{"tx" => %{"tx" => %{"tx" => %{"pointers" => pointers}}}} -> pointers
    end
    |> Enum.into(%{}, fn %{"id" => id} -> {"account_pubkey", id} end)
  end

  defp render_ownership([{{_bi, _txi}, last_claim_txi} | _rest_claims], transfers) do
    orig_owner =
      last_claim_txi
      |> Txs.fetch!()
      |> case do
        %{"tx" => %{"account_id" => account_id}} -> account_id
        %{"tx" => %{"tx" => %{"tx" => %{"account_id" => account_id}}}} -> account_id
      end

    case transfers do
      [] ->
        %{original: orig_owner, current: orig_owner}

      [{{_bi, _txi}, last_transfer_txi} | _rest_transfers] ->
        %{"tx" => %{"recipient_id" => curr_owner}} = Txs.fetch!(last_transfer_txi)

        %{original: orig_owner, current: curr_owner}
    end
  end

  defp serialize_name_cursor(name), do: name

  defp deserialize_name_cursor(nil), do: nil

  defp deserialize_name_cursor(cursor_bin) do
    case Regex.run(~r/\A([\w\.]+\.chain)\z/, cursor_bin) do
      [_match0, name] -> name
      nil -> nil
    end
  end

  defp serialize_expiration_cursor(nil), do: nil

  defp serialize_expiration_cursor({exp_height, name}), do: "#{exp_height}-#{name}"

  defp deserialize_expiration_cursor(nil), do: nil

  defp deserialize_expiration_cursor(cursor_bin) do
    case Regex.run(~r/\A(\d+)-([\w\.]+)\z/, cursor_bin) do
      [_match0, exp_height, name] -> {String.to_integer(exp_height), name}
      nil -> nil
    end
  end

  defp expand_txi(bi_txi, false), do: bi_txi
  defp expand_txi(bi_txi, true), do: Format.to_map(Util.read_tx!(bi_txi))

  defp render_previous(name, expand?) do
    name
    |> Stream.unfold(fn
      Model.name(previous: nil) -> nil
      Model.name(previous: previous) -> {previous, previous}
    end)
    |> Enum.map(&render_name_info(&1, expand?))
  end

  defp deserialize_scope({:gen, %Range{first: first_gen, last: last_gen}}, direction) do
    if direction == :forward do
      {{first_gen, <<>>}, {last_gen, <<>>}}
    else
      {{first_gen, nil}, {last_gen, nil}}
    end
  end

  defp deserialize_scope(_nil_or_txis_scope, _direction), do: nil
end

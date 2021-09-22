defmodule AeMdw.Names do
  @moduledoc """
  Context module for dealing with Names.
  """

  require AeMdw.Db.Model

  alias AeMdw.AuctionBids
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.Collection
  alias AeMdw.Mnesia
  alias AeMdw.Node
  alias AeMdw.Txs

  @type cursor :: binary()
  # This needs to be an actual type like AeMdw.Db.Name.t()
  @type name :: term()
  @typep order_by :: :expiration | :name
  @typep limit :: Mnesia.limit()
  @typep direction :: Mnesia.direction()

  @table_active Model.ActiveName
  @table_active_expiration Model.ActiveNameExpiration
  @table_inactive Model.InactiveName
  @table_inactive_expiration Model.InactiveNameExpiration

  @spec fetch_names(direction(), order_by(), cursor() | nil, limit(), boolean()) ::
          {[name()], cursor() | nil}
  def fetch_names(direction, :expiration, cursor, limit, expand?) do
    cursor = deserialize_expiration_cursor(cursor)

    {{start_table, start_keys}, {end_table, end_keys}, next_key} =
      Collection.concat(
        @table_inactive_expiration,
        @table_active_expiration,
        direction,
        cursor,
        limit
      )

    start_names = render_exp_list(start_keys, start_table == @table_active_expiration, expand?)
    end_names = render_exp_list(end_keys, end_table == @table_active_expiration, expand?)

    {start_names ++ end_names, serialize_expiration_cursor(next_key)}
  end

  def fetch_names(direction, :name, cursor, limit, expand?) do
    cursor = deserialize_name_cursor(cursor)

    {name_keys, next_key} =
      Collection.merge([@table_active, @table_inactive], direction, cursor, limit)

    names =
      Enum.map(name_keys, fn {plain_name, source} ->
        render(plain_name, source == @table_active, expand?)
      end)

    {names, serialize_name_cursor(next_key)}
  end

  @spec fetch_active_names(direction(), order_by(), cursor() | nil, limit(), boolean()) ::
          {[name()], cursor() | nil}
  def fetch_active_names(direction, :name, cursor, limit, expand?) do
    {name_keys, next_cursor} =
      Mnesia.fetch_keys(@table_active, direction, deserialize_name_cursor(cursor), limit)

    {render_names_list(name_keys, true, expand?), serialize_name_cursor(next_cursor)}
  end

  def fetch_active_names(direction, :expiration, cursor, limit, expand?) do
    {exp_keys, next_cursor} =
      Mnesia.fetch_keys(
        @table_active_expiration,
        direction,
        deserialize_expiration_cursor(cursor),
        limit
      )

    {render_exp_list(exp_keys, true, expand?), serialize_expiration_cursor(next_cursor)}
  end

  @spec fetch_inactive_names(direction(), order_by(), cursor() | nil, limit(), boolean()) ::
          {[name()], cursor() | nil}
  def fetch_inactive_names(direction, :name, cursor, limit, expand?) do
    {name_keys, next_cursor} =
      Mnesia.fetch_keys(@table_inactive, direction, deserialize_name_cursor(cursor), limit)

    {render_names_list(name_keys, false, expand?), serialize_name_cursor(next_cursor)}
  end

  def fetch_inactive_names(direction, :expiration, cursor, limit, expand?) do
    {exp_keys, next_cursor} =
      Mnesia.fetch_keys(
        @table_inactive_expiration,
        direction,
        deserialize_expiration_cursor(cursor),
        limit
      )

    {render_exp_list(exp_keys, false, expand?), serialize_expiration_cursor(next_cursor)}
  end

  @spec fetch_previous_list(name()) :: [name()]
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

  defp render_names_list(names_keys, is_active?, expand?) do
    Enum.map(names_keys, &render(&1, is_active?, expand?))
  end

  defp render_exp_list(names_keys, is_active?, expand?) do
    Enum.map(names_keys, fn {_exp, plain_name} -> render(plain_name, is_active?, expand?) end)
  end

  defp render(plain_name, is_active?, expand?) do
    name = Mnesia.fetch!(if(is_active?, do: @table_active, else: @table_inactive), plain_name)

    {status, auction_bid} =
      case AuctionBids.top_auction_bid(plain_name) do
        {:ok, auction_bid} -> {:auction, auction_bid}
        :not_found -> {:name, nil}
      end

    %{
      name: plain_name,
      auction: auction_bid && render_auction_bid_info(auction_bid),
      status: status,
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
    %{tx: %{pointers: pointers}} = Txs.fetch!(txi)

    pointers
    |> Enum.map(fn ptr -> {:aens_pointer.key(ptr), render_account_id(:aens_pointer.id(ptr))} end)
    |> Map.new()
  end

  defp render_ownership([{{_bi, _txi}, last_claim_txi} | _rest_claims], transfers) do
    %{tx: %{account_id: orig_owner}} = Txs.fetch!(last_claim_txi)

    case transfers do
      [] ->
        %{original: orig_owner, current: orig_owner}

      [{{_bi, _txi}, last_transfer_txi} | _rest_transfers] ->
        %{tx: %{recipient_id: curr_owner}} = Txs.fetch!(last_transfer_txi)

        %{original: orig_owner, current: curr_owner}
    end
  end

  defp render_auction_bid_info(%{info: %{last_bid: last_bid} = auction_info}) do
    %{block_hash: block_hash, hash: hash, signatures: signatures, tx: %{type: type} = tx} =
      last_bid

    new_last_bid = %{
      last_bid
      | block_hash: :aeser_api_encoder.encode(:micro_block_hash, block_hash),
        hash: :aeser_api_encoder.encode(:tx_hash, hash),
        signatures: Enum.map(signatures, &:aeser_api_encoder.encode(:signature, &1)),
        tx: %{tx | type: Node.tx_name(type)}
    }

    %{auction_info | last_bid: new_last_bid}
  end

  defp serialize_name_cursor(nil), do: nil

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

  defp render_account_id({:id, id_type, payload}) do
    :aeser_api_encoder.encode(Node.id_type(id_type), payload)
  end
end

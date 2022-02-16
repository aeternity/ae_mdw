defmodule AeMdw.Oracles do
  @moduledoc """
  Context module for dealing with Oracles.
  """

  require AeMdw.Db.Model

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util, as: DBUtil
  alias AeMdw.Database
  alias AeMdw.Node
  alias AeMdw.Util

  @type cursor :: binary()
  # This needs to be an actual type like AeMdw.Db.Oracle.t()
  @type oracle :: term()
  @type pagination :: Collection.direction_limit()
  @typep range :: {:gen, Range.t()} | nil

  @table_active AeMdw.Db.Model.ActiveOracle
  @table_active_expiration Model.ActiveOracleExpiration
  @table_inactive AeMdw.Db.Model.InactiveOracle
  @table_inactive_expiration Model.InactiveOracleExpiration

  @spec fetch_oracles(pagination(), range(), cursor() | nil, boolean()) ::
          {cursor() | nil, [oracle()], cursor() | nil}
  def fetch_oracles(pagination, scope, cursor, expand?) do
    cursor = deserialize_cursor(cursor)

    gen_range =
      case scope do
        nil ->
          nil

        {:gen, %Range{first: first_gen, last: last_gen}} ->
          {{first_gen, Util.min_bin()}, {last_gen, Util.max_256bit_bin()}}
      end

    {:ok, {last_gen, -1}} = Database.last_key(Model.Block)

    {prev_cursor, expiration_keys, next_cursor} =
      fn direction ->
        active_stream =
          @table_active_expiration
          |> Collection.stream(direction, gen_range, cursor)
          |> Stream.map(fn key -> {key, @table_active_expiration} end)

        inactive_stream =
          @table_inactive_expiration
          |> Collection.stream(direction, gen_range, cursor)
          |> Stream.map(fn key -> {key, @table_inactive_expiration} end)

        case direction do
          :forward -> Stream.concat(inactive_stream, active_stream)
          :backward -> Stream.concat(active_stream, inactive_stream)
        end
      end
      |> Collection.paginate(pagination)

    oracles =
      Enum.map(expiration_keys, fn {key, tab} ->
        render(key, last_gen, tab == @table_active_expiration, expand?)
      end)

    {serialize_cursor(prev_cursor), oracles, serialize_cursor(next_cursor)}
  end

  @spec fetch_active_oracles(pagination(), cursor() | nil, boolean()) ::
          {cursor() | nil, [oracle()], cursor() | nil}
  def fetch_active_oracles(pagination, cursor, expand?) do
    cursor = deserialize_cursor(cursor)
    {:ok, {last_gen, -1}} = Database.last_key(Model.Block)

    {prev_cursor, exp_keys, next_cursor} =
      Collection.paginate(
        &Collection.stream(@table_active_expiration, &1, nil, cursor),
        pagination
      )

    oracles = render_list(exp_keys, last_gen, true, expand?)

    {serialize_cursor(prev_cursor), oracles, serialize_cursor(next_cursor)}
  end

  @spec fetch_inactive_oracles(pagination(), cursor() | nil, boolean()) ::
          {cursor() | nil, [oracle()], cursor() | nil}
  def fetch_inactive_oracles(pagination, cursor, expand?) do
    cursor = deserialize_cursor(cursor)
    {:ok, {last_gen, -1}} = Database.last_key(Model.Block)

    {prev_cursor, exp_keys, next_cursor} =
      Collection.paginate(
        &Collection.stream(@table_inactive_expiration, &1, nil, cursor),
        pagination
      )

    oracles = render_list(exp_keys, last_gen, false, expand?)

    {serialize_cursor(prev_cursor), oracles, serialize_cursor(next_cursor)}
  end

  defp render_list(oracles_keys, last_gen, is_active?, expand?) do
    Enum.map(oracles_keys, &render(&1, last_gen, is_active?, expand?))
  end

  defp render({_exp, oracle_pk}, last_gen, is_active?, expand?) do
    Model.oracle(
      index: pk,
      expire: expire_height,
      register: {{register_height, _mbi}, register_txi},
      extends: extends,
      previous: _previous
    ) = Database.fetch!(if(is_active?, do: @table_active, else: @table_inactive), oracle_pk)

    kbi = min(expire_height - 1, last_gen)

    block_hash = Blocks.block_hash(kbi)
    oracle_tree = AeMdw.Db.Oracle.oracle_tree!(block_hash)
    oracle_rec = :aeo_state_tree.get_oracle(pk, oracle_tree)

    %{
      oracle: :aeser_api_encoder.encode(:oracle_pubkey, pk),
      active: is_active?,
      active_from: register_height,
      expire_height: expire_height,
      register: expand_txi(register_txi, expand?),
      extends: Enum.map(extends, &expand_txi(Format.bi_txi_txi(&1), expand?)),
      query_fee: Node.Oracle.get!(oracle_rec, :query_fee),
      format: %{
        query: Node.Oracle.get!(oracle_rec, :query_format),
        response: Node.Oracle.get!(oracle_rec, :response_format)
      }
    }
  end

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor({{{exp_height, oracle_pk}, _tab}, is_reversed?}),
    do: serialize_cursor({{exp_height, oracle_pk}, is_reversed?})

  defp serialize_cursor({{exp_height, oracle_pk}, is_reversed?}),
    do: {"#{exp_height}-#{:aeser_api_encoder.encode(:oracle_pubkey, oracle_pk)}", is_reversed?}

  defp deserialize_cursor(nil), do: nil

  defp deserialize_cursor(cursor_bin) do
    with [_match0, exp_height, encoded_pk] <- Regex.run(~r/(\d+)-(ok_\w+)/, cursor_bin),
         {:ok, pk} <- :aeser_api_encoder.safe_decode(:oracle_pubkey, encoded_pk) do
      {String.to_integer(exp_height), pk}
    else
      _nil_or_error -> nil
    end
  end

  defp expand_txi(bi_txi, false), do: bi_txi
  defp expand_txi(bi_txi, true), do: Format.to_map(DBUtil.read_tx!(bi_txi))
end

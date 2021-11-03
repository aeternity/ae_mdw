defmodule AeMdw.Oracles do
  @moduledoc """
  Context module for dealing with Oracles.
  """

  require AeMdw.Db.Model

  alias AeMdw.Collection
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.Mnesia
  alias AeMdw.Node

  @type cursor :: binary()
  # This needs to be an actual type like AeMdw.Db.Oracle.t()
  @type oracle :: term()
  @typep limit :: Mnesia.limit()
  @typep scope :: {:gen, Range.t()} | nil

  @table_active AeMdw.Db.Model.ActiveOracle
  @table_active_expiration Model.ActiveOracleExpiration
  @table_inactive AeMdw.Db.Model.InactiveOracle
  @table_inactive_expiration Model.InactiveOracleExpiration

  @spec fetch_oracles(Mnesia.direction(), scope(), cursor() | nil, limit(), boolean()) ::
          {[oracle()], cursor() | nil}
  def fetch_oracles(direction, scope, cursor, limit, expand?) do
    cursor = deserialize_cursor(cursor)
    gen_range =
      case scope do
        nil -> nil
        {:gen, %Range{first: first_gen, last: last_gen}} ->
          if direction == :forward do
            {{first_gen, <<>>}, {last_gen, <<>>}}
          else
            {{first_gen, nil}, {last_gen, nil}}
          end
      end

    active_stream =
      @table_active_expiration
      |> Collection.stream(direction, gen_range, cursor)
      |> Stream.map(fn key -> {key, @table_active_expiration} end)
    inactive_stream =
      @table_inactive_expiration
      |> Collection.stream(direction, gen_range, cursor)
      |> Stream.map(fn key -> {key, @table_inactive_expiration} end)

    stream =
      case direction do
        :forward -> Stream.concat(inactive_stream, active_stream)
        :backward -> Stream.concat(active_stream, inactive_stream)
      end

    {:ok, {last_gen, -1}} = Mnesia.last_key(AeMdw.Db.Model.Block)

    {oracles_keys, cursor} = Collection.paginate(stream, limit)
    oracles =
      Enum.map(oracles_keys, fn {key, tab} -> render(key, last_gen, tab == @table_active_expiration, expand?) end)

    case cursor do
      nil -> {oracles, nil}
      {next_key, _next_key_table} -> {oracles, serialize_cursor(next_key)}
    end
  end

  @spec fetch_active_oracles(Mnesia.direction(), cursor() | nil, limit(), boolean()) ::
          {[oracle()], cursor() | nil}
  def fetch_active_oracles(direction, cursor, limit, expand?) do
    {exp_keys, next_cursor} =
      Mnesia.fetch_keys(@table_active_expiration, direction, deserialize_cursor(cursor), limit)

    {:ok, {last_gen, -1}} = Mnesia.last_key(AeMdw.Db.Model.Block)

    oracles = render_list(exp_keys, last_gen, true, expand?)

    {oracles, serialize_cursor(next_cursor)}
  end

  @spec fetch_inactive_oracles(Mnesia.direction(), cursor() | nil, limit(), boolean()) ::
          {[oracle()], cursor() | nil}
  def fetch_inactive_oracles(direction, cursor, limit, expand?) do
    {exp_keys, next_cursor} =
      Mnesia.fetch_keys(@table_inactive_expiration, direction, deserialize_cursor(cursor), limit)

    {:ok, {last_gen, -1}} = Mnesia.last_key(AeMdw.Db.Model.Block)

    oracles = render_list(exp_keys, last_gen, false, expand?)

    {oracles, serialize_cursor(next_cursor)}
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
    ) = Mnesia.fetch!(if(is_active?, do: @table_active, else: @table_inactive), oracle_pk)

    kbi = min(expire_height - 1, last_gen)

    oracle_tree = AeMdw.Db.Oracle.oracle_tree!({kbi, -1})
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

  defp serialize_cursor({exp_height, oracle_pk}) do
    "#{exp_height}-#{:aeser_api_encoder.encode(:oracle_pubkey, oracle_pk)}"
  end

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
  defp expand_txi(bi_txi, true), do: Format.to_map(Util.read_tx!(bi_txi))
end

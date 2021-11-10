defmodule AeMdw.Blocks do
  @moduledoc """
  Context module for dealing with Blocks.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.EtsCache
  alias AeMdw.Mnesia
  alias AeMdw.Validate

  require Model

  # This needs to be an actual type like AeMdw.Db.Tx.t()
  @type block :: term()
  @type cursor :: binary()

  @typep direction :: Mnesia.direction()
  @typep limit :: Mnesia.limit()
  @typep range :: {:gen, Range.t()} | nil

  @table Model.Block

  @cache_table __MODULE__
  @blocks_cache_threshold 6

  @spec create_cache_table() :: :ok
  def create_cache_table do
    generations_cache_exp = Application.fetch_env!(:ae_mdw, :generations_cache_expiration_minutes)

    EtsCache.new(@cache_table, generations_cache_exp, :ordered_set)
  end

  @spec fetch_blocks(direction(), range(), cursor() | nil, limit(), boolean()) ::
          {[block()], cursor() | nil}
  def fetch_blocks(direction, range, cursor, limit, expand?) do
    {:ok, {last_gen, -1}} = Mnesia.last_key(AeMdw.Db.Model.Block)

    range_scope = deserialize_scope(range)

    cursor_scope =
      case deserialize_cursor(cursor) do
        nil -> nil
        cursor when direction == :forward -> {cursor, cursor + limit + 1}
        cursor -> {cursor, cursor - limit - 1}
      end

    global_scope = if direction == :forward, do: {0, last_gen}, else: {last_gen, 0}

    case intersect_scopes([range_scope, cursor_scope, global_scope], direction) do
      {:ok, first, last} when last - first > limit ->
        {render_blocks(first, first + limit - 1, last_gen, expand?),
         serialize_cursor(first + limit)}

      {:ok, first, last} when first - last > limit ->
        {render_blocks(first, first - limit + 1, last_gen, expand?),
         serialize_cursor(first - limit)}

      {:ok, first, last} ->
        {render_blocks(first, last, last_gen, expand?), nil}

      :empty ->
        {[], nil}
    end
  end

  defp intersect_scopes(scopes, direction) do
    scopes
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(fn
      {first, last}, {acc_first, acc_last} when direction == :forward ->
        {max(first, acc_first), min(last, acc_last)}

      {first, last}, {acc_first, acc_last} ->
        {min(first, acc_first), max(last, acc_last)}
    end)
    |> case do
      {first, last} when direction == :forward and first <= last -> {:ok, first, last}
      {_first, _last} when direction == :forward -> :empty
      {first, last} when direction == :backward and first >= last -> {:ok, first, last}
      {_first, _last} when direction == :backward -> :empty
    end
  end

  defp render_blocks(from, to, last_gen, expand?),
    do: Enum.map(from..to, &render(&1, last_gen, expand?))

  defp render(gen, last_gen, expand?) when gen > last_gen - @blocks_cache_threshold do
    [key_block | micro_blocks] = fetch_gen_blocks(gen, last_gen)

    put_mbs_from_db(key_block, micro_blocks, expand?)
  end

  defp render(gen, last_gen, expand?) do
    [key_block | micro_blocks] = fetch_gen_blocks(gen, last_gen)

    fetch_gen_from_cache(gen, key_block, micro_blocks, expand?)
  end

  defp fetch_gen_blocks(last_gen, last_gen) do
    # gets by height once the chain current generation might happen to be higher than last_gen in DB
    {:ok, %{key_block: kb, micro_blocks: mbs}} =
      :aec_chain.get_generation_by_height(last_gen, :forward)

    ^last_gen = :aec_blocks.height(kb)

    for block <- [kb | mbs] do
      header = :aec_blocks.to_header(block)
      :aec_headers.serialize_for_client(header, Util.prev_block_type(header))
    end
  end

  defp fetch_gen_blocks(gen, _last_gen) do
    @table
    |> Collection.stream(:backward, nil, {gen, <<>>})
    |> Stream.take_while(&match?({^gen, _mb_index}, &1))
    |> Enum.map(fn key -> Mnesia.fetch!(@table, key) end)
    |> Enum.reverse()
    |> Enum.map(fn block -> Format.to_map(block) end)
  end

  defp fetch_gen_from_cache(gen, key_block, micro_blocks, expand?) do
    case EtsCache.get(@cache_table, gen) do
      {key_block, _indx} ->
        key_block

      nil ->
        key_block = put_mbs_from_db(key_block, micro_blocks, expand?)
        EtsCache.put(@cache_table, gen, key_block)
        key_block
    end
  end

  defp put_mbs_from_db(key_block, micro_blocks, false) do
    micro_blocks =
      micro_blocks
      |> db_read_mbs()
      |> Map.new()

    Map.put(key_block, "micro_blocks", micro_blocks)
  end

  defp put_mbs_from_db(key_block, micro_blocks, true) do
    micro_blocks =
      micro_blocks
      |> db_read_mbs()
      |> Enum.map(fn {_mb_hash, micro_block} -> micro_block end)
      |> Enum.sort_by(fn %{"time" => time} -> time end)

    Map.put(key_block, "micro_blocks", micro_blocks)
  end

  defp db_read_mbs(micro_blocks) do
    micro_blocks
    |> Enum.map(fn %{"hash" => mb_hash} = micro_block ->
      micro = :aec_db.get_block(Validate.id!(mb_hash))
      header = :aec_blocks.to_header(micro)

      txs =
        for tx <- :aec_blocks.txs(micro), into: %{} do
          %{"hash" => tx_hash} = tx = :aetx_sign.serialize_for_client(header, tx)

          {tx_hash, tx}
        end

      micro_block = Map.put(micro_block, "transactions", txs)

      {mb_hash, micro_block}
    end)
  end

  defp serialize_cursor(gen), do: Integer.to_string(gen)

  defp deserialize_cursor(nil), do: nil

  defp deserialize_cursor(cursor_bin) do
    case Integer.parse(cursor_bin) do
      {n, ""} when n >= 0 -> n
      {_n, _rest} -> nil
      :error -> nil
    end
  end

  defp deserialize_scope(nil), do: nil

  defp deserialize_scope({:gen, %Range{first: first_gen, last: last_gen}}),
    do: {first_gen, last_gen}
end

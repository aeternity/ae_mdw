defmodule AeMdw.Blocks do
  @moduledoc """
  Context module for dealing with Blocks.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.EtsCache
  alias AeMdw.Database
  alias AeMdw.Util
  alias AeMdw.Validate

  require Model

  @type height() :: non_neg_integer()
  @type mbi() :: non_neg_integer()
  @type time() :: non_neg_integer()
  @type block_index() :: {height(), mbi()}
  @type txi_pos() :: non_neg_integer() | -1
  @type block_index_txi_pos() :: {height(), txi_pos()}
  @type key_header() :: term()
  @type key_hash() :: <<_::32>>
  @type block_hash() :: <<_::256>>

  @type block :: map()
  @type cursor :: binary()

  @typep direction :: Database.direction()
  @typep limit :: Database.limit()
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
          {cursor() | nil, [block()], cursor() | nil}
  def fetch_blocks(direction, range, cursor, limit, sort_mbs?) do
    {:ok, {last_gen, -1}} = Database.last_key(AeMdw.Db.Model.Block)

    cursor = deserialize_cursor(cursor)

    {range_first, range_last} =
      case range do
        nil -> {0, last_gen}
        {:gen, %Range{first: first, last: last}} -> {max(first, 0), min(last, last_gen)}
      end

    case Util.build_gen_pagination(cursor, direction, range_first, range_last, limit) do
      {:ok, prev_cursor, range, next_cursor} ->
        {serialize_cursor(prev_cursor), render_blocks(range, last_gen, sort_mbs?),
         serialize_cursor(next_cursor)}

      :error ->
        {nil, [], nil}
    end
  end

  @spec block_hash(height()) :: block_hash()
  def block_hash(height) do
    Model.block(hash: hash) = Database.fetch!(@table, {height, -1})

    hash
  end

  defp render_blocks(range, last_gen, sort_mbs?),
    do: Enum.map(range, &render(&1, last_gen, sort_mbs?))

  defp render(gen, last_gen, sort_mbs?) when gen > last_gen - @blocks_cache_threshold do
    [key_block | micro_blocks] = fetch_gen_blocks(gen, last_gen)

    put_mbs_from_db(key_block, micro_blocks, sort_mbs?)
  end

  defp render(gen, last_gen, sort_mbs?) do
    [key_block | micro_blocks] = fetch_gen_blocks(gen, last_gen)

    fetch_gen_from_cache(gen, key_block, micro_blocks, sort_mbs?)
  end

  defp fetch_gen_blocks(last_gen, last_gen) do
    # gets by height once the chain current generation might happen to be higher than last_gen in DB
    {:ok, %{key_block: kb, micro_blocks: mbs}} =
      :aec_chain.get_generation_by_height(last_gen, :forward)

    ^last_gen = :aec_blocks.height(kb)

    for block <- [kb | mbs] do
      header = :aec_blocks.to_header(block)
      :aec_headers.serialize_for_client(header, DbUtil.prev_block_type(header))
    end
  end

  defp fetch_gen_blocks(gen, _last_gen) do
    @table
    |> Collection.stream(:backward, nil, {gen, <<>>})
    |> Stream.take_while(&match?({^gen, _mb_index}, &1))
    |> Enum.map(fn key -> Database.fetch!(@table, key) end)
    |> Enum.reverse()
    |> Enum.map(fn block -> Format.to_map(block) end)
  end

  defp fetch_gen_from_cache(gen, key_block, micro_blocks, sort_mbs?) do
    case EtsCache.get(@cache_table, gen) do
      {key_block, _indx} ->
        key_block

      nil ->
        key_block = put_mbs_from_db(key_block, micro_blocks, sort_mbs?)
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

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor(gen), do: {Integer.to_string(gen), false}

  defp deserialize_cursor(nil), do: nil

  defp deserialize_cursor(cursor_bin) do
    case Integer.parse(cursor_bin) do
      {n, ""} when n >= 0 -> n
      {_n, _rest} -> nil
      :error -> nil
    end
  end
end

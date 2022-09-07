defmodule AeMdw.Blocks do
  @moduledoc """
  Context module for dealing with Blocks.
  """

  alias AeMdw.Collection
  alias AeMdw.Error
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Database
  alias AeMdw.Node.Db
  alias AeMdw.Util
  alias AeMdw.Validate
  alias AeMdw.Txs

  require Model

  @type height() :: non_neg_integer()
  @type mbi() :: non_neg_integer()
  @type time() :: non_neg_integer()
  @type block_index() :: {height(), mbi() | -1}
  @type txi_pos() :: non_neg_integer() | -1
  @type block_index_txi_pos() :: {height(), txi_pos()}
  @type block_index_txi() :: {block_index(), Txs.txi()}
  @type bi_txi() :: block_index_txi()
  @type key_header() :: term()
  @type block_hash() :: <<_::256>>

  @type block :: map()
  @type cursor :: binary()

  @typep direction :: Database.direction()
  @typep limit :: Database.limit()
  @typep range :: {:gen, Range.t()} | nil

  @table Model.Block

  @spec fetch_blocks(State.t(), direction(), range(), cursor() | nil, limit(), boolean()) ::
          {cursor() | nil, [block()], cursor() | nil}
  def fetch_blocks(state, direction, range, cursor, limit, sort_mbs?) do
    last_gen = DbUtil.last_gen(state)
    cursor = deserialize_cursor(cursor)

    range =
      case range do
        nil -> {0, last_gen}
        {:gen, %Range{first: first, last: last}} -> {first, last}
      end

    case Util.build_gen_pagination(cursor, direction, range, limit, last_gen) do
      {:ok, prev_cursor, range, next_cursor} ->
        {serialize_cursor(prev_cursor), render_blocks(state, range, sort_mbs?),
         serialize_cursor(next_cursor)}

      :error ->
        {nil, [], nil}
    end
  end

  @spec block_hash(State.t(), height()) :: block_hash()
  def block_hash(state, height) do
    Model.block(hash: hash) = State.fetch!(state, @table, {height, -1})

    hash
  end

  @spec fetch(State.t(), block_index() | block_hash()) :: {:ok, block()} | {:error, Error.t()}
  def fetch(_state, block_hash) when is_binary(block_hash) do
    with {:ok, encoded_hash} <- Validate.id(block_hash),
         {:ok, _block} <- :aec_chain.get_block(encoded_hash) do
      header = :aec_db.get_header(encoded_hash)

      {:ok, :aec_headers.serialize_for_client(header, Db.prev_block_type(header))}
    else
      :error -> {:error, Error.Input.NotFound.exception(value: block_hash)}
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch(state, block_index) do
    case State.get(state, @table, block_index) do
      {:ok, Model.block(hash: block_hash)} -> fetch(state, block_hash)
      :not_found -> {:error, Error.Input.NotFound.exception(value: block_index)}
    end
  end

  @spec fetch_txis_from_gen(State.t(), height()) :: Enumerable.t()
  def fetch_txis_from_gen(state, height) do
    with {:ok, Model.block(tx_index: tx_index_start)}
         when is_integer(tx_index_start) and tx_index_start >= 0 <-
           State.get(state, @table, {height, -1}),
         {:ok, Model.block(tx_index: tx_index_end)}
         when is_integer(tx_index_end) and tx_index_end >= 0 <-
           State.get(state, @table, {height + 1, -1}) do
      tx_index_start..tx_index_end
    else
      _full_block_not_found -> []
    end
  end

  defp render_blocks(state, range, sort_mbs?) do
    Enum.map(range, fn gen ->
      [key_block | micro_blocks] =
        state
        |> Collection.stream(@table, :backward, nil, {gen, <<>>})
        |> Stream.take_while(&match?({^gen, _mb_index}, &1))
        |> Enum.map(fn key -> State.fetch!(state, @table, key) end)
        |> Enum.reverse()
        |> Enum.map(fn Model.block(index: {_height, _mbi}, hash: hash) ->
          header = :aec_db.get_header(hash)

          :aec_headers.serialize_for_client(header, Db.prev_block_type(header))
        end)

      put_mbs_from_db(key_block, micro_blocks, sort_mbs?)
    end)
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

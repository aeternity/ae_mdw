defmodule AeMdw.Blocks do
  @moduledoc """
  Context module for dealing with Blocks.
  """

  alias AeMdw.Collection
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Db.IntTransfer
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
  @type block_index_txi() :: {block_index(), Txs.txi()}
  @type bi_txi() :: block_index_txi()
  @type bi_txi_idx() :: {block_index(), Txs.txi_idx()}
  @type key_header() :: term()
  @type block_hash() :: <<_::256>>

  @type block :: map()
  @type cursor :: binary()

  @typep state() :: State.t()
  @typep direction :: Database.direction()
  @typep limit :: Database.limit()
  @typep scope() :: {:gen, Range.t()} | nil
  @typep page_cursor() :: Collection.pagination_cursor()

  @table Model.Block

  @spec fetch_key_blocks(State.t(), direction(), scope(), cursor() | nil, limit()) ::
          {:ok, {cursor() | nil, [block()], cursor() | nil}} | {:error, Error.t()}
  def fetch_key_blocks(state, direction, scope, cursor, limit) do
    with {:ok, cursor} <- deserialize_cursor(cursor),
         {:ok, last_gen} <- DbUtil.last_gen(state),
         {:ok, scope} <- deserialize_scope(scope, last_gen) do
      case Util.build_gen_pagination(cursor, direction, scope, limit, last_gen) do
        {:ok, prev_cursor, range, next_cursor} ->
          {:ok,
           {serialize_cursor(prev_cursor), render_key_blocks(state, range),
            serialize_cursor(next_cursor)}}

        :error ->
          {:ok, {nil, [], nil}}
      end
    else
      {:error, reason} -> {:error, reason}
      :none -> {:ok, {nil, [], nil}}
    end
  end

  @spec fetch_key_block(state(), binary()) :: {:ok, block()} | {:error, Error.t()}
  def fetch_key_block(state, hash_or_kbi) do
    with {:ok, height} <- DbUtil.key_block_height(state, hash_or_kbi) do
      {:ok, render_key_block(state, height)}
    end
  end

  @spec fetch_micro_block(State.t(), binary()) :: {:ok, block()} | {:error, Error.t()}
  def fetch_micro_block(state, hash) do
    with {:ok, height, mbi} <- DbUtil.micro_block_height_index(state, hash) do
      if State.exists?(state, Model.Block, {height, mbi}) do
        {:ok, render_micro_block(state, height, mbi)}
      else
        {:error, ErrInput.NotFound.exception(value: hash)}
      end
    end
  end

  @spec fetch_key_block_micro_blocks(
          State.t(),
          binary(),
          Collection.direction_limit(),
          cursor() | nil
        ) ::
          {:ok, {page_cursor(), [block()], page_cursor()}} | {:error, Error.t()}
  def fetch_key_block_micro_blocks(state, hash_or_kbi, pagination, cursor) do
    with {:ok, cursor} <- deserialize_cursor(cursor),
         {:ok, height} <- DbUtil.key_block_height(state, hash_or_kbi) do
      cursor = if cursor, do: {height, cursor}

      paginated_blocks =
        fn direction ->
          state
          |> Collection.stream(
            Model.Block,
            direction,
            {{height, 0}, {height, Util.max_int()}},
            cursor
          )
          |> Stream.map(fn {_height, mbi} -> mbi end)
        end
        |> Collection.paginate(
          pagination,
          &render_micro_block(state, height, &1),
          &serialize_micro_cursor/1
        )

      {:ok, paginated_blocks}
    end
  end

  @spec fetch_blocks(State.t(), direction(), scope(), cursor() | nil, limit()) ::
          {:ok, {cursor() | nil, [block()], cursor() | nil}} | {:error, Error.t()}
  def fetch_blocks(state, direction, scope, cursor, limit) do
    with {:ok, cursor} <- deserialize_cursor(cursor),
         {:ok, last_gen} <- DbUtil.last_gen(state),
         {:ok, scope} <- deserialize_scope(scope, last_gen) do
      case Util.build_gen_pagination(cursor, direction, scope, limit, last_gen) do
        {:ok, prev_cursor, range, next_cursor} ->
          {:ok,
           {serialize_cursor(prev_cursor), render_blocks(state, range),
            serialize_cursor(next_cursor)}}

        :error ->
          {:ok, {nil, [], nil}}
      end
    else
      {:error, reason} -> {:error, reason}
      :none -> {nil, [], nil}
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
    case State.get(state, @table, {height, -1}) do
      {:ok, Model.block(tx_index: tx_index_start)} ->
        tx_index_end =
          case State.get(state, @table, {height + 1, -1}) do
            {:ok, Model.block(tx_index: tx_index_end)} -> tx_index_end - 1
            :not_found -> last_txi(state, -1)
          end

        if tx_index_end >= tx_index_start do
          tx_index_start..tx_index_end
        else
          []
        end

      :not_found ->
        []
    end
  end

  @spec block_index_to_hash(State.t(), block_index()) :: block_hash()
  def block_index_to_hash(state, block_index) do
    Model.block(hash: hash) = State.fetch!(state, Model.Block, block_index)

    hash
  end

  defp render_key_blocks(state, range), do: Enum.map(range, &render_key_block(state, &1))

  defp render_key_block(state, gen) do
    mbi_count =
      case State.prev(state, @table, {gen + 1, -1}) do
        {:ok, {^gen, mbi}} -> mbi + 1
        {:ok, _block_index} -> 0
        :none -> 0
      end

    txs_count =
      case State.prev(state, @table, {gen + 1, 0}) do
        {:ok, block_index} ->
          Model.block(tx_index: next_tx_index) = State.fetch!(state, @table, block_index)
          Model.block(tx_index: first_tx_index) = State.fetch!(state, @table, {gen, -1})
          next_tx_index - first_tx_index

        :none ->
          0
      end

    Model.block(hash: hash) = State.fetch!(state, @table, {gen, -1})
    header = :aec_db.get_header(hash)

    block_reward =
      case State.get(state, Model.DeltaStat, gen) do
        {:ok, Model.delta_stat(block_reward: block_reward)} ->
          block_reward

        :not_found ->
          IntTransfer.read_block_reward(state, gen)
      end

    header
    |> :aec_headers.serialize_for_client(Db.prev_block_type(header))
    |> Map.put(:micro_blocks_count, mbi_count)
    |> Map.put(:transactions_count, txs_count)
    |> Map.put(:beneficiary_reward, block_reward)
  end

  defp render_micro_block(state, height, mbi) do
    Model.block(tx_index: first_tx_index, hash: mb_hash) =
      State.fetch!(state, Model.Block, {height, mbi})

    txs_count =
      case State.next(state, @table, {height, mbi}) do
        {:ok, block_index} ->
          Model.block(tx_index: next_tx_index) = State.fetch!(state, @table, block_index)
          next_tx_index - first_tx_index

        :none ->
          # last micro-block, fetch last transaction instead because no next block
          with {:ok, txi} <- State.prev(state, Model.Tx, nil),
               Model.tx(block_index: {^height, ^mbi}) <- State.fetch!(state, Model.Tx, txi) do
            txi + 1 - first_tx_index
          else
            _none_or_no_txs -> 0
          end
      end

    block = :aec_db.get_block(mb_hash)
    header = :aec_blocks.to_header(block)
    gas = :aec_blocks.gas(block)

    header
    |> :aec_headers.serialize_for_client(Db.prev_block_type(header))
    |> Map.put(:micro_block_index, mbi)
    |> Map.put(:transactions_count, txs_count)
    |> Map.put(:gas, gas)
  end

  defp render_blocks(state, range) do
    Enum.map(range, fn gen ->
      [key_block | micro_blocks] =
        state
        |> Collection.stream(@table, :backward, nil, {gen, Util.max_int()})
        |> Stream.take_while(&match?({^gen, _mb_index}, &1))
        |> Enum.reverse()
        |> Enum.map(fn block_index ->
          Model.block(hash: hash) = State.fetch!(state, @table, block_index)
          header = :aec_db.get_header(hash)

          :aec_headers.serialize_for_client(header, Db.prev_block_type(header))
        end)

      blocks_txs =
        state
        |> fetch_txis_from_gen(gen)
        |> Enum.map(fn txi ->
          state
          |> Txs.fetch!(txi)
          |> Map.delete("tx_index")
        end)
        |> Enum.group_by(fn %{"block_hash" => block_hash} -> block_hash end)

      put_mbs_from_db(key_block, micro_blocks, blocks_txs)
    end)
  end

  defp put_mbs_from_db(key_block, micro_blocks, blocks_txs) do
    micro_blocks =
      micro_blocks
      |> db_read_mbs(blocks_txs)
      |> Enum.map(fn {_mb_hash, micro_block} -> micro_block end)
      |> Enum.sort_by(fn %{"time" => time} -> time end)

    Map.put(key_block, "micro_blocks", micro_blocks)
  end

  defp db_read_mbs(micro_blocks, blocks_txs) do
    Enum.map(micro_blocks, fn %{"hash" => mb_hash} = micro_block ->
      txs =
        blocks_txs
        |> Map.get(mb_hash, [])
        |> Map.new(fn %{"hash" => tx_hash} = tx -> {tx_hash, tx} end)

      micro_block = Map.put(micro_block, "transactions", txs)

      {mb_hash, micro_block}
    end)
  end

  defp deserialize_scope(nil, last_gen), do: {:ok, {0, last_gen}}

  defp deserialize_scope({:gen, first..last//_step}, _last_gen), do: {:ok, {first, last}}

  defp deserialize_scope(invalid_scope, _last_gen),
    do: {:error, ErrInput.Scope.exception(value: invalid_scope)}

  defp serialize_micro_cursor(mbi), do: Integer.to_string(mbi)

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor(gen), do: {Integer.to_string(gen), false}

  defp deserialize_cursor(nil), do: {:ok, nil}

  defp deserialize_cursor(cursor_bin) do
    case Integer.parse(cursor_bin) do
      {n, ""} when n >= 0 -> {:ok, n}
      _invalid_cursor -> {:error, ErrInput.Cursor.exception(value: cursor_bin)}
    end
  end

  defp last_txi(state, default) do
    case DbUtil.last_txi(state) do
      {:ok, txi} -> txi
      :none -> default
    end
  end
end

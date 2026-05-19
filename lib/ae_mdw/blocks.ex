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
  alias :aeser_api_encoder, as: Enc

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

  @spec fetch_key_block(state(), binary(), keyword()) :: {:ok, block()} | {:error, Error.t()}
  def fetch_key_block(state, hash_or_kbi, opts \\ []) do
    with {:ok, height} <- DbUtil.key_block_height(state, hash_or_kbi),
         :ok <- ensure_hash_key_block_available(state, height, hash_or_kbi, opts),
         %{} = key_block <- render_key_block(state, height) do
      {:ok, key_block}
    else
      nil -> {:error, ErrInput.NotFound.exception(value: hash_or_kbi)}
      {:error, reason} -> {:error, reason}
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
         {:ok, header} <- fetch_header(encoded_hash) do
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

  defp fetch_header(block_hash) do
    try do
      with {:ok, _block} <- :aec_chain.get_block(block_hash) do
        {:ok, :aec_db.get_header(block_hash)}
      end
    rescue
      ArgumentError -> :error
      UndefinedFunctionError -> :error
    catch
      :exit, _reason -> :error
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

  defp render_key_blocks(state, range) do
    range
    |> Enum.map(&render_key_block(state, &1))
    |> Enum.reject(&is_nil/1)
  end

  defp render_key_block(state, gen) do
    case State.get(state, @table, {gen, -1}) do
      {:ok, Model.block(hash: hash, tx_index: first_tx_index)} ->
        mbi_count = micro_blocks_count(state, gen)
        txs_count = key_block_transactions_count(state, gen, first_tx_index)
        block_reward = key_block_reward(state, gen)

        render_key_block_payload(state, gen, hash, mbi_count, txs_count, block_reward)

      :not_found ->
        nil
    end
  end

  defp micro_blocks_count(state, gen) do
    case State.prev(state, @table, {gen + 1, -1}) do
      {:ok, {^gen, mbi}} -> mbi + 1
      {:ok, _block_index} -> 0
      :none -> 0
    end
  end

  defp key_block_transactions_count(state, gen, first_tx_index) do
    case State.prev(state, @table, {gen + 1, 0}) do
      {:ok, block_index} ->
        case State.get(state, @table, block_index) do
          {:ok, Model.block(tx_index: next_tx_index)}
          when is_integer(next_tx_index) and is_integer(first_tx_index) ->
            next_tx_index - first_tx_index

          :not_found ->
            0

          _other_block ->
            0
        end

      :none ->
        0
    end
  end

  defp key_block_reward(state, gen) do
    case State.get(state, Model.DeltaStat, gen) do
      {:ok, Model.delta_stat(block_reward: block_reward)} ->
        block_reward

      :not_found ->
        IntTransfer.read_block_reward(state, gen)
    end
  end

  defp render_key_block_payload(state, gen, hash, mbi_count, txs_count, block_reward) do
    case fetch_key_header(hash) do
      {:ok, header} ->
        header
        |> :aec_headers.serialize_for_client(Db.prev_block_type(header))
        |> Map.put(:micro_blocks_count, mbi_count)
        |> Map.put(:transactions_count, txs_count)
        |> Map.put(:beneficiary_reward, block_reward)

      :error ->
        %{
          beneficiary_reward: block_reward,
          hash: Enc.encode(:key_block_hash, hash),
          height: gen,
          micro_blocks_count: mbi_count,
          time: DbUtil.block_index_to_time(state, {gen, -1}),
          transactions_count: txs_count
        }
    end
  end

  defp fetch_key_header(block_hash) do
    try do
      {:ok, :aec_db.get_header(block_hash)}
    rescue
      ArgumentError -> :error
      UndefinedFunctionError -> :error
    catch
      :exit, _reason -> :error
    end
  end

  defp ensure_hash_key_block_available(state, height, hash_or_kbi, opts) do
    strict_hash? = Keyword.get(opts, :strict_hash?, true)

    case Util.parse_int(hash_or_kbi) do
      {:ok, _height} ->
        :ok

      :error when strict_hash? ->
        with {:ok, Model.block(hash: hash)} <- State.get(state, @table, {height, -1}),
             {:ok, _header} <- fetch_key_header(hash) do
          :ok
        else
          _missing_header -> {:error, ErrInput.NotFound.exception(value: hash_or_kbi)}
        end

      :error ->
        :ok
    end
  end

  defp render_micro_block(state, height, mbi) do
    block_rec = State.fetch!(state, Model.Block, {height, mbi})
    Model.block(tx_index: first_tx_index) = block_rec
    mb_hash = Model.block(block_rec, :hash)

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

    case fetch_micro_block_data(mb_hash) do
      {:ok, block, header} ->
        header
        |> :aec_headers.serialize_for_client(Db.prev_block_type(header))
        |> Map.put(:micro_block_index, mbi)
        |> Map.put(:transactions_count, txs_count)
        |> Map.put(:gas, :aec_blocks.gas(block))

      :error ->
        %{
          gas: 0,
          hash: maybe_encode_micro_block_hash(mb_hash),
          height: height,
          micro_block_index: mbi,
          time: DbUtil.block_index_to_time(state, {height, mbi}),
          transactions_count: txs_count
        }
    end
  end

  defp maybe_encode_micro_block_hash(block_hash) do
    try do
      Enc.encode(:micro_block_hash, block_hash)
    rescue
      ArgumentError -> nil
      FunctionClauseError -> nil
    end
  end

  defp fetch_micro_block_data(block_hash) do
    try do
      block = :aec_db.get_block(block_hash)
      {:ok, block, :aec_blocks.to_header(block)}
    rescue
      ArgumentError -> :error
      UndefinedFunctionError -> :error
      FunctionClauseError -> :error
    catch
      :exit, _reason -> :error
    end
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

defmodule AeMdw.Db.Util do
  @moduledoc false

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.InnerTx
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Util
  alias AeMdw.Validate

  require Model

  @typep state() :: State.t()
  @typep height() :: Blocks.height()
  @typep txi() :: Txs.txi()
  @typep time() :: Blocks.time()
  @typep block_index() :: Blocks.block_index()

  @tx_types_to_fname %{
    :contract_create_tx => ~w(Chain.clone Chain.create),
    :ga_attach_tx => ~w(),
    :oracle_response_tx => ~w(Oracle.respond)
  }

  @approximate_key_block_rate 3 * 60 * 1_000

  @spec read_tx!(state(), Txs.txi()) :: Model.tx()
  def read_tx!(state, txi), do: State.fetch!(state, Model.Tx, txi)

  @spec read_block!(state(), Blocks.block_index()) :: Model.block()
  def read_block!(state, block_index), do: State.fetch!(state, Model.Block, block_index)

  @spec last_txi(state()) :: {:ok, Txs.txi()} | :none
  def last_txi(state), do: State.prev(state, Model.Tx, nil)

  @spec last_txi!(state()) :: Txs.txi()
  def last_txi!(state) do
    {:ok, txi} = last_txi(state)

    txi
  end

  @spec last_gen!(state()) :: Blocks.height()
  def last_gen!(state) do
    case last_gen(state) do
      {:ok, height} -> height
      :none -> raise RuntimeError, message: "can't get last key for table Model.Block"
    end
  end

  @spec last_gen(state()) :: {:ok, Blocks.height()} | :none
  def last_gen(state) do
    with {:ok, {height, _mbi}} <- State.prev(state, Model.Block, nil) do
      {:ok, height}
    end
  end

  @spec last_gen_and_time!(state()) :: {Blocks.height(), Blocks.time()}
  def last_gen_and_time!(state) do
    case last_gen_and_time(state) do
      {:ok, gen_time} -> gen_time
      :no_blocks -> raise RuntimeError, message: "can't get last key for table Model.Block"
    end
  end

  # Reads time from MDW index tables first (Model.Time, Model.KeyBlockTime) to
  # avoid a node DB call via block_time/1. Falls back to approximation when the
  # state is sparse (test fixtures) and none of the time tables are populated.
  @spec last_gen_and_time(state()) :: {:ok, {Blocks.height(), Blocks.time()}} | :no_blocks
  def last_gen_and_time(state) do
    case {State.prev(state, Model.Block, nil), State.prev(state, Model.Time, nil),
          State.prev(state, Model.KeyBlockTime, nil), State.prev(state, Model.Tx, nil)} do
      {{:ok, {height, _mbi}}, {:ok, {time, _txi}}, _key_block_time, _last_tx} ->
        {:ok, {height, time}}

      {{:ok, {height, _mbi}}, :none, {:ok, time}, _last_tx} ->
        {:ok, {height, time}}

      {{:ok, {height, _mbi}}, :none, :none, {:ok, txi}} ->
        case State.get(state, Model.Tx, txi) do
          {:ok, Model.tx(time: time)} when is_integer(time) ->
            {:ok, {height, time}}

          _missing_time ->
            {:ok, {height, last_block_time_or_approx(state, height)}}
        end

      {{:ok, {height, _mbi}}, :none, :none, :none} ->
        {:ok, {height, last_block_time_or_approx(state, height)}}

      {:none, _no_time, _no_key_block_time, _no_tx} ->
        :no_blocks
    end
  end

  @spec block_txi(state(), Blocks.block_index()) :: Txs.txi() | nil
  def block_txi(state, bi) do
    case State.get(state, Model.Block, bi) do
      {:ok, Model.block(tx_index: txi)} -> txi
      :not_found -> nil
    end
  end

  @spec block_hash_to_bi(state(), Blocks.block_hash()) :: Blocks.block_index() | nil
  def block_hash_to_bi(state, block_hash) do
    with {:ok, node_block} <- :aec_chain.get_block(block_hash),
         {:ok, last_gen} <- last_gen(state),
         {:micro, height} when height < last_gen <- block_type_height(node_block) do
      state
      |> Collection.stream(Model.Block, :forward, {{height, 0}, {height, nil}}, nil)
      |> Enum.find(fn bi ->
        case read_block!(state, bi) do
          Model.block(hash: ^block_hash) -> bi
          _other_block -> nil
        end
      end)
    else
      :none -> nil
      :error -> nil
      {:key, height} -> {height, -1}
      {:micro, _non_synced_height} -> nil
    end
  end

  @spec gen_to_txi(state(), Blocks.height()) :: Txs.txi()
  def gen_to_txi(state, gen) do
    case State.get(state, Model.Block, {gen, -1}) do
      {:ok, Model.block(tx_index: txi)} ->
        txi

      :not_found ->
        case State.prev(state, Model.Tx, nil) do
          {:ok, last_txi} -> last_txi + 1
          :none -> 0
        end
    end
  end

  @spec first_gen_to_txi(state(), height()) :: height()
  def first_gen_to_txi(state, first_gen), do: gen_to_txi(state, first_gen)

  @spec last_gen_to_txi(state(), height()) :: height()
  def last_gen_to_txi(state, last_gen), do: gen_to_txi(state, last_gen + 1) - 1

  @spec txi_to_gen(state(), Txs.txi()) :: Blocks.height()
  def txi_to_gen(state, txi) do
    case State.get(state, Model.Tx, txi) do
      {:ok, Model.tx(block_index: {kbi, _mbi})} ->
        kbi

      :not_found ->
        case State.prev(state, Model.Block, nil) do
          {:ok, {last_kbi, _mbi}} -> last_kbi + 1
          :none -> 0
        end
    end
  end

  @spec time_to_txi(state(), integer(), integer()) :: {Txs.txi(), Txs.txi()}
  def time_to_txi(state, first, last) do
    case {State.next(state, Model.Time, {first, -1}), State.prev(state, Model.Time, {last, nil})} do
      {{:ok, {_first_time, first_txi}}, {:ok, {_second_time, last_txi}}} ->
        {first_txi, last_txi}

      {_first_error, _second_error} ->
        {-1, -1}
    end
  end

  @spec txi_to_time(state(), Txs.txi()) :: time()
  def txi_to_time(state, txi) do
    Model.tx(time: time) = State.fetch!(state, Model.Tx, txi)

    time
  end

  @spec height_hash(Blocks.height()) :: Blocks.block_hash()
  def height_hash(height) do
    {:ok, block} = :aec_chain.get_key_block_by_height(height)
    {:ok, hash} = :aec_headers.hash_header(:aec_blocks.to_header(block))

    hash
  end

  @spec synced_height(state()) :: Blocks.height() | -1
  def synced_height(state) do
    case State.prev(state, Model.DeltaStat, nil) do
      :none -> -1
      {:ok, height} -> height
    end
  end

  @spec key_block_height(state(), binary()) :: {:ok, Blocks.height()} | {:error, Error.t()}
  def key_block_height(state, hash_or_kbi) do
    with {:ok, kbi} when kbi >= 0 <- Util.parse_int(hash_or_kbi),
         {:ok, last_gen} when kbi <= last_gen <- last_gen(state) do
      {:ok, kbi}
    else
      :error ->
        with {:ok, height, _hash} <- extract_block_height(state, hash_or_kbi, :key_block_hash) do
          {:ok, height}
        end

      _invalid_kbi ->
        {:error, ErrInput.NotFound.exception(value: hash_or_kbi)}
    end
  end

  @spec micro_block_height_index(state(), binary()) ::
          {:ok, Blocks.height(), Blocks.mbi()} | {:error, Error.t()}
  def micro_block_height_index(state, mb_hash) do
    with {:ok, height, decoded_hash} <- extract_block_height(state, mb_hash, :micro_block_hash) do
      mbi =
        decoded_hash
        |> Db.get_reverse_micro_blocks()
        |> Enum.count()

      {:ok, height, mbi}
    end
  end

  @spec read_node_tx(state(), Txs.txi_idx()) :: Node.tx()
  def read_node_tx(state, txi_idx) do
    {tx, _inner_type, _tx_hash, _tx_type, _block_hash} = read_node_tx_details(state, txi_idx)
    tx
  end

  @spec read_node_tx_details(state(), Txs.txi_idx()) ::
          {Node.tx(), Node.tx_type(), Txs.tx_hash(), Node.tx_type(), Blocks.block_hash()}
  def read_node_tx_details(state, {txi, -1}) do
    Model.tx(id: tx_hash) = State.fetch!(state, Model.Tx, txi)
    {block_hash, tx_type, _signed_tx, tx_rec} = Db.get_tx_data(tx_hash)

    if tx_type in [:ga_meta_tx, :paying_for_tx] do
      {inner_type, tx} =
        tx_type
        |> InnerTx.signed_tx(tx_rec)
        |> :aetx_sign.tx()
        |> :aetx.specialize_type()

      {tx, inner_type, tx_hash, tx_type, block_hash}
    else
      {tx_rec, tx_type, tx_hash, tx_type, block_hash}
    end
  end

  def read_node_tx_details(state, {txi, local_idx}) do
    Model.tx(id: tx_hash) = State.fetch!(state, Model.Tx, txi)

    Model.int_contract_call(tx: aetx) =
      State.fetch!(state, Model.IntContractCall, {txi, local_idx})

    {block_hash, tx_type, _signed_tx, _tx_rec} = Db.get_tx_data(tx_hash)

    {inner_type, tx} = :aetx.specialize_type(aetx)

    {tx, inner_type, tx_hash, tx_type, block_hash}
  end

  def read_node_tx_details(state, txi), do: read_node_tx_details(state, {txi, -1})

  # Nil-safe variant of read_node_tx_details/2. Used in GraphQL resolvers where the
  # MDW state may be sparse (e.g. in tests with synthetic fixtures that have no
  # corresponding node-DB entries). Returns nil instead of raising on a missing tx.
  @spec read_node_tx_details_safe(state(), Txs.txi_idx() | txi()) ::
          {Node.tx(), Node.tx_type(), Txs.tx_hash(), Node.tx_type(), Blocks.block_hash()} | nil
  def read_node_tx_details_safe(state, {txi, -1}) do
    with {:ok, Model.tx(id: tx_hash)} <- State.get(state, Model.Tx, txi),
         {block_hash, tx_type, _signed_tx, tx_rec} <- Db.get_tx_data(tx_hash) do
      if tx_type in [:ga_meta_tx, :paying_for_tx] do
        {inner_type, tx} =
          tx_type
          |> InnerTx.signed_tx(tx_rec)
          |> :aetx_sign.tx()
          |> :aetx.specialize_type()

        {tx, inner_type, tx_hash, tx_type, block_hash}
      else
        {tx_rec, tx_type, tx_hash, tx_type, block_hash}
      end
    else
      _missing_tx -> nil
    end
  end

  def read_node_tx_details_safe(state, {txi, local_idx}) do
    with {:ok, Model.tx(id: tx_hash)} <- State.get(state, Model.Tx, txi),
         {:ok, Model.int_contract_call(tx: aetx)} <-
           State.get(state, Model.IntContractCall, {txi, local_idx}),
         {block_hash, tx_type, _signed_tx, _tx_rec} <- Db.get_tx_data(tx_hash) do
      {inner_type, tx} = :aetx.specialize_type(aetx)

      {tx, inner_type, tx_hash, tx_type, block_hash}
    else
      _missing_tx -> nil
    end
  end

  def read_node_tx_details_safe(state, txi), do: read_node_tx_details_safe(state, {txi, -1})

  @spec transactions_of_type(
          state(),
          Node.tx_type(),
          Collection.direction(),
          Collection.key_boundary(),
          Collection.cursor()
        ) :: Enumerable.t()
  def transactions_of_type(state, tx_type, direction, scope, cursor) do
    internal_txs =
      @tx_types_to_fname
      |> Map.fetch!(tx_type)
      |> Enum.map(fn fname ->
        cursor =
          case cursor do
            nil -> nil
            {txi, idx} -> {fname, txi, idx}
          end

        key_boundary =
          case scope do
            nil -> {{fname, Util.min_int(), 0}, {fname, Util.max_int(), Util.max_int()}}
            {txi_start, txi_end} -> {{fname, txi_start, 0}, {fname, txi_end, Util.max_int()}}
          end

        state
        |> Collection.stream(Model.FnameIntContractCall, direction, key_boundary, cursor)
        |> Stream.map(fn {^fname, call_txi, local_idx} -> {call_txi, local_idx} end)
      end)

    cursor =
      case cursor do
        nil -> nil
        {txi, _idx} -> {tx_type, txi}
      end

    key_boundary =
      case scope do
        nil -> {{tx_type, Util.min_int()}, {tx_type, Util.max_int()}}
        {txi_start, txi_end} -> {{tx_type, txi_start}, {tx_type, txi_end}}
      end

    raw_txs =
      state
      |> Collection.stream(Model.Type, direction, key_boundary, cursor)
      |> Stream.map(fn {^tx_type, txi} -> {txi, -1} end)

    inner_txs =
      state
      |> Collection.stream(Model.InnerType, direction, key_boundary, cursor)
      |> Stream.map(fn {^tx_type, txi} -> {txi, -1} end)

    Collection.merge([raw_txs, inner_txs | internal_txs], direction)
  end

  defp extract_block_height(state, encoded_hash, type) do
    with {:ok, hash} <- Validate.hash(encoded_hash, type),
         {:ok, height} <- find_block_height(state, hash, type) do
      {:ok, height, hash}
    else
      {:error, reason} -> {:error, reason}
      _error_or_invalid_height -> {:error, ErrInput.NotFound.exception(value: encoded_hash)}
    end
  end

  defp find_block_height(state, hash, type) do
    with {:ok, last_gen} <- last_gen(state),
         {:ok, height} when height <= last_gen <- Node.Db.find_block_height(hash) do
      {:ok, height}
    else
      # Block is in the node DB but beyond MDW's current indexed height –
      # not yet visible to the middleware, treat as not-found without scanning.
      {:ok, _height_beyond_mdw} ->
        :error

      # Block missing (:none) or the node DB is temporarily unavailable (:error,
      # e.g. node restart, a transient reorg during active sync, or sparse test
      # fixtures). MDW's own index is the source of truth for what the API
      # exposes, so fall back to the bounded scan of the MDW Block collection.
      _missing_or_error ->
        find_block_height_in_state(state, hash, type)
    end
  end

  # Scans the MDW Block collection to locate a block by hash when the node DB
  # is temporarily unavailable (e.g. during a node restart or in sparse test
  # fixtures where aec_db is not fully initialised).
  defp find_block_height_in_state(state, hash, type) do
    with {:ok, last_gen} <- last_gen(state),
         block_index when not is_nil(block_index) <-
           state
           |> Collection.stream(Model.Block, :forward, {{0, -1}, {last_gen, Util.max_int()}}, nil)
           |> Enum.find(fn {_, mbi} = block_index ->
             matches_type? =
               case type do
                 :key_block_hash -> mbi == -1
                 :micro_block_hash -> mbi >= 0
               end

             matches_type? and
               match?({:ok, Model.block(hash: ^hash)}, State.get(state, Model.Block, block_index))
           end) do
      {:ok, elem(block_index, 0)}
    else
      _not_found -> :error
    end
  end

  defp block_type_height(node_block) do
    {type, header} =
      case node_block do
        {:key_block, header} -> {:key, header}
        {:mic_block, header, _txs, _fraud} -> {:micro, header}
      end

    {type, :aec_headers.height(header)}
  end

  @spec call_account_pk(state(), txi()) :: Db.pubkey()
  def call_account_pk(state, call_txi) do
    case read_node_tx_details(state, {call_txi, -1}) do
      {tx, _inner_type, _tx_hash, :contract_call_tx, _block_hash} ->
        tx |> :aect_call_tx.caller_id() |> :aeser_id.specialize(:account)

      {tx, _inner_type, _tx_hash, :contract_create_tx, _block_hash} ->
        tx |> :aect_create_tx.owner_id() |> :aeser_id.specialize(:account)
    end
  end

  @spec height_to_time(state(), height(), height(), time()) :: time()
  def height_to_time(state, height, last_height, last_micro_time) when height <= last_height do
    case State.get(state, Model.Block, {height, -1}) do
      {:ok, Model.block(hash: block_hash)} ->
        case fetch_block_time(block_hash) do
          {:ok, time} -> time
          :error -> relative_height_time(height, last_height, last_micro_time)
        end

      :not_found ->
        relative_height_time(height, last_height, last_micro_time)
    end
  end

  def height_to_time(_state, height, last_height, last_micro_time),
    do: last_micro_time + (height - last_height) * @approximate_key_block_rate

  @spec block_index_to_time(state(), block_index()) :: time()
  def block_index_to_time(state, block_index) do
    case State.get(state, Model.Block, block_index) do
      {:ok, Model.block(hash: block_hash)} ->
        case fetch_block_time(block_hash) do
          {:ok, time} -> time
          :error -> relative_block_time(state, elem(block_index, 0))
        end

      :not_found ->
        relative_block_time(state, elem(block_index, 0))
    end
  end

  @spec block_time(Blocks.block_hash()) :: time()
  def block_time(block_hash) do
    block_hash
    |> :aec_db.get_header()
    |> :aec_headers.time_in_msecs()
  end

  # Wraps block_time/1 to return :error instead of raising when the hash is absent
  # from the node DB (e.g. synthetic hashes in sparse test fixtures).
  defp fetch_block_time(block_hash) do
    try do
      {:ok, block_time(block_hash)}
    rescue
      ArgumentError -> :error
      UndefinedFunctionError -> :error
    catch
      :exit, _reason -> :error
    end
  end

  defp last_block_time_or_approx(state, height) do
    case State.get(state, Model.Block, {height, -1}) do
      {:ok, Model.block(hash: block_hash)} ->
        case fetch_block_time(block_hash) do
          {:ok, time} -> time
          :error -> approximate_height_time(height)
        end

      :not_found ->
        approximate_height_time(height)
    end
  end

  defp relative_block_time(state, height) do
    case last_gen_and_time(state) do
      {:ok, {last_height, last_micro_time}} ->
        relative_height_time(height, last_height, last_micro_time)

      :no_blocks ->
        approximate_height_time(height)
    end
  end

  defp relative_height_time(height, last_height, last_micro_time),
    do: last_micro_time + (height - last_height) * @approximate_key_block_rate

  defp approximate_height_time(height), do: height * @approximate_key_block_rate

  @spec network_date_interval(state()) :: {Date.t(), Date.t()}
  def network_date_interval(state) do
    case State.prev(state, Model.Time, nil) do
      {:ok, {end_time, _end_tx_index}} ->
        {:ok, {start_time, _start_tx_index}} = State.next(state, Model.Time, nil)

        [start_date, end_date] =
          [start_time, end_time]
          |> Enum.map(&DateTime.to_date(DateTime.from_unix!(div(&1, 1_000))))

        {start_date, end_date}

      :none ->
        {:ok, start_date} = Date.new(2018, 12, 11)
        {start_date, start_date}
    end
  end
end

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

  @spec last_gen(state()) :: Blocks.height()
  def last_gen(state) do
    case State.prev(state, Model.Block, nil) do
      {:ok, {height, _mbi}} -> height
      :none -> raise RuntimeError, message: "can't get last key for table Model.Block"
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
         last_gen <- last_gen(state),
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
    case Util.parse_int(hash_or_kbi) do
      {:ok, kbi} when kbi >= 0 ->
        last_gen = last_gen(state)

        if kbi <= last_gen do
          {:ok, kbi}
        else
          {:error, ErrInput.NotFound.exception(value: hash_or_kbi)}
        end

      {:ok, _kbi} ->
        {:error, ErrInput.NotFound.exception(value: hash_or_kbi)}

      :error ->
        with {:ok, height, _hash} <- extract_height_hash(state, :key, hash_or_kbi) do
          {:ok, height}
        end
    end
  end

  @spec micro_block_height_index(state(), binary()) ::
          {:ok, Blocks.height(), Blocks.mbi()} | {:error, Error.t()}
  def micro_block_height_index(state, mb_hash) do
    with {:ok, height, decoded_hash} <- extract_height_hash(state, :micro, mb_hash) do
      mbi =
        decoded_hash
        |> Db.get_reverse_micro_blocks()
        |> Enum.count()

      {:ok, height, mbi}
    end
  end

  @spec read_node_tx(state(), Txs.txi_idx()) :: Node.tx()
  def read_node_tx(state, txi_idx) do
    {tx, _tx_hash, _tx_type} = read_node_tx_details(state, txi_idx)
    tx
  end

  @spec read_node_tx_details(state(), Txs.txi_idx()) :: {Node.tx(), Txs.tx_hash(), Node.tx_type()}
  def read_node_tx_details(state, {txi, -1}) do
    Model.tx(id: tx_hash) = State.fetch!(state, Model.Tx, txi)
    {_block_hash, tx_type, _signed_tx, tx_rec} = Db.get_tx_data(tx_hash)

    if tx_type in [:ga_meta_tx, :paying_for_tx] do
      {_type, tx} =
        tx_type
        |> InnerTx.signed_tx(tx_rec)
        |> :aetx_sign.tx()
        |> :aetx.specialize_type()

      {tx, tx_hash, tx_type}
    else
      {tx_rec, tx_hash, tx_type}
    end
  end

  def read_node_tx_details(state, {txi, local_idx}) do
    Model.tx(id: tx_hash) = State.fetch!(state, Model.Tx, txi)

    Model.int_contract_call(tx: aetx) =
      State.fetch!(state, Model.IntContractCall, {txi, local_idx})

    {_block_hash, tx_type, _signed_tx, _tx_rec} = Db.get_tx_data(tx_hash)

    {_type, tx} = :aetx.specialize_type(aetx)

    {tx, tx_hash, tx_type}
  end

  defp extract_height_hash(state, type, hash) do
    with {:ok, encoded_hash} <- Validate.id(hash),
         {:ok, block} <- :aec_chain.get_block(encoded_hash),
         header <- :aec_blocks.to_header(block),
         ^type <- :aec_headers.type(header),
         last_gen <- last_gen(state),
         height when height <= last_gen <- :aec_headers.height(header) do
      {:ok, height, encoded_hash}
    else
      {:error, reason} -> {:error, reason}
      _error_or_invalid_height -> {:error, ErrInput.NotFound.exception(value: hash)}
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
      {tx, _tx_hash, :contract_call_tx} ->
        tx |> :aect_call_tx.caller_id() |> :aeser_id.specialize(:account)

      {tx, _tx_hash, :contract_create_tx} ->
        tx |> :aect_create_tx.owner_id() |> :aeser_id.specialize(:account)
    end
  end
end

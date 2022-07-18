defmodule AeMdw.Db.Util do
  @moduledoc false

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Txs

  require Model

  @typep state() :: State.t()

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

  defp block_type_height(node_block) do
    {type, header} =
      case node_block do
        {:key_block, header} -> {:key, header}
        {:mic_block, header, _txs, _fraud} -> {:micro, header}
      end

    {type, :aec_headers.height(header)}
  end
end

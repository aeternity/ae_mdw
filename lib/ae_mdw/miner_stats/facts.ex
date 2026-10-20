defmodule AeMdw.MinerStats.Facts do
  @moduledoc """
  Reads from the node and the database what's needed to know about a generation
  (a key block and its micro blocks) to fold it into the mining stats.
  """

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Node.Db
  alias AeMdw.Util

  require Model

  @type t() :: %{
          height: Blocks.height(),
          time: Blocks.time(),
          miner: Db.pubkey(),
          beneficiary: Db.pubkey(),
          info: non_neg_integer() | nil,
          difficulty: non_neg_integer(),
          micro_blocks: non_neg_integer(),
          txs: non_neg_integer(),
          fees: non_neg_integer(),
          rewards: %{Db.pubkey() => pos_integer()}
        }

  @doc """
  The rewards are the ones paid in the generation, for blocks mined some generations
  before, and the fees the ones of the transactions the generation processed.
  """
  @spec fetch(State.t(), Blocks.height()) :: {:ok, t()} | {:error, atom()}
  def fetch(state, height) do
    with {:ok, header} <- Db.get_key_header(height) do
      {first_txi, next_txi} = txi_range(state, height)

      {:ok,
       %{
         height: height,
         time: :aec_headers.time_in_msecs(header),
         miner: :aec_headers.miner(header),
         beneficiary: :aec_headers.beneficiary(header),
         info: info(header),
         difficulty: :aec_headers.difficulty(header),
         micro_blocks: micro_blocks_count(state, height),
         txs: next_txi - first_txi,
         fees: fees(state, first_txi, next_txi),
         rewards: IntTransfer.sum_block_rewards_by_target(state, height, height)
       }}
    end
  end

  defp info(header) do
    case :aec_headers.info(header) do
      info when is_integer(info) -> info
      _default -> nil
    end
  end

  # The first txi of a generation is the one stored with its key block, which is also
  # the next txi of the previous one.
  defp txi_range(state, height) do
    first_txi = block_txi(state, height) || 0

    next_txi =
      case block_txi(state, height + 1) do
        nil ->
          case DbUtil.last_txi(state) do
            {:ok, last_txi} -> last_txi + 1
            :none -> first_txi
          end

        txi ->
          txi
      end

    {first_txi, next_txi}
  end

  defp block_txi(state, height), do: DbUtil.block_txi(state, {height, -1})

  defp micro_blocks_count(state, height) do
    state
    |> Collection.stream(Model.Block, :forward, {{height, 0}, {height, Util.max_int()}}, nil)
    |> Enum.count()
  end

  defp fees(state, first_txi, next_txi) do
    first_txi..(next_txi - 1)//1
    |> Enum.reduce(0, fn txi, acc ->
      case State.get(state, Model.Tx, txi) do
        {:ok, Model.tx(fee: fee)} when is_integer(fee) -> acc + fee
        _no_fee -> acc
      end
    end)
  end
end

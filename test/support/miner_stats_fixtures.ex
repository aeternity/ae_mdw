defmodule AeMdw.MinerStatsFixtures do
  @moduledoc """
  A small mining history shared by the mining stats tests:

      height  bucket  miner  beneficiary  rewards paid
      20      1       m1     b1
      21      1       m2     b1           b1: 50
      22      1       m1     b2           b2: 70, b1: 5
      40      2       m1     b1
      41      2       m3     b3           b2: 9
      60      3       m1     b1
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.MinerStats.Fold

  require Model

  @m1 <<1::256>>
  @m2 <<2::256>>
  @m3 <<3::256>>
  @b1 <<11::256>>
  @b2 <<12::256>>
  @b3 <<13::256>>

  @spec miners() :: [binary()]
  def miners, do: [@m1, @m2, @m3]

  @spec beneficiaries() :: [binary()]
  def beneficiaries, do: [@b1, @b2, @b3]

  @spec fold_history(State.t()) :: State.t()
  def fold_history(state) do
    [
      facts(20, @m1, @b1, txs: 3, fees: 30, info: 1, micro_blocks: 2, time: 1_000),
      facts(21, @m2, @b1,
        txs: 1,
        fees: 10,
        info: 1,
        micro_blocks: 1,
        time: 2_000,
        rewards: %{@b1 => 50}
      ),
      facts(22, @m1, @b2, difficulty: 200, info: 2, time: 3_000, rewards: %{@b2 => 70, @b1 => 5}),
      facts(40, @m1, @b1, txs: 2, fees: 5, info: 2, time: 4_000),
      facts(41, @m3, @b3, info: 2, time: 5_000, rewards: %{@b2 => 9}),
      facts(60, @m1, @b1, info: 2, time: 6_000)
    ]
    |> Enum.reduce(state, &Fold.fold(&2, &1))
    |> State.put(Model.Stat, Model.stat(index: :miner_stats_height, payload: 60))
  end

  defp facts(height, miner, beneficiary, opts) do
    %{
      height: height,
      time: Keyword.fetch!(opts, :time),
      miner: miner,
      beneficiary: beneficiary,
      info: Keyword.get(opts, :info),
      difficulty: Keyword.get(opts, :difficulty, 100),
      micro_blocks: Keyword.get(opts, :micro_blocks, 0),
      txs: Keyword.get(opts, :txs, 0),
      fees: Keyword.get(opts, :fees, 0),
      rewards: Keyword.get(opts, :rewards, %{})
    }
  end
end

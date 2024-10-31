defmodule AeMdw.Migrations.AddHyperchainLeaders do
  @moduledoc """
  Generate leaders for hyperchain.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Hyperchain

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    {:ok, %{last: last_height}} = :aec_chain_hc.epoch_info()

    stream =
      Stream.resource(
        fn -> 1 end,
        fn
          too_big when too_big > last_height ->
            {:halt, too_big}

          height ->
            leaders = Hyperchain.leaders_for_epoch_at_height(height)
            {leaders, height + length(leaders)}
        end,
        fn _ -> :ok end
      )

    stream
    |> Stream.map(fn {height, leader} ->
      WriteMutation.new(
        Model.HyperchainLeaderAtHeight,
        Model.hyperchain_leader_at_height(index: height, leader: leader)
      )
    end)
    |> Stream.chunk_every(1000)
    |> Stream.map(fn mutations ->
      _new_state = State.commit_db(state, mutations)

      length(mutations)
    end)
    |> Enum.sum()
    |> then(&{:ok, &1})
  end
end

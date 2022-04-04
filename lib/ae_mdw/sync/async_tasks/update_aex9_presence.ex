defmodule AeMdw.Sync.AsyncTasks.UpdateAex9State do
  @moduledoc """
  Async work to update AEX9 presence and balance through dry-run.
  """
  @behaviour AeMdw.Sync.AsyncTasks.Work

  alias AeMdw.Node.Db, as: DBN

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.UpdateAex9PresenceMutation
  alias AeMdw.Log

  require Model
  require Logger

  @microsecs 1_000_000
  @min_height 500_000

  @spec process(args :: list()) :: :ok
  def process([contract_pk]) do
    Log.info("[update_aex9_state] #{inspect(contract_pk)} ...")
    {_type, height, _hash} = height_hash = DBN.top_height_hash(false)

    if height > @min_height do
      {time_delta, {balances, _height_hash}} =
        :timer.tc(fn -> DBN.aex9_balances(contract_pk, height_hash) end)

      Log.info("[update_aex9_state] #{inspect(contract_pk)} after #{time_delta / @microsecs}s")

      balances =
        Enum.map(balances, fn {{:address, account_pk}, amount} -> {account_pk, amount} end)

      mutation = UpdateAex9PresenceMutation.new(contract_pk, balances)
      state = State.new()
      State.commit(state, [mutation])
    end

    :ok
  end
end

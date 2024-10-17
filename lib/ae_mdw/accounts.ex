defmodule AeMdw.Accounts do
  @moduledoc """
    Module for account related operations
  """
  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Stats, as: SyncStats
  alias AeMdw.Node.Db

  require Model

  @spec maybe_increase_creation_statistics(State.t(), Db.pubkey(), Blocks.time()) :: State.t()
  def maybe_increase_creation_statistics(state, pubkey, time) do
    state
    |> State.get(Model.AccountCreation, pubkey)
    |> case do
      :not_found ->
        state
        |> State.put(
          Model.AccountCreation,
          Model.account_creation(index: pubkey, creation_time: time)
        )
        |> SyncStats.increment_statistics(:total_accounts, time, 1)

      _account_creation ->
        state
    end
  end
end

defmodule AeMdw.Db.Oracle do
  @moduledoc """
  Cache through operations for active and inactive oracles.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db

  require Model

  @typep pubkey :: Db.pubkey()
  @typep state :: State.t()

  @spec locate(state(), pubkey()) ::
          {Model.oracle(), Model.ActiveOracle | Model.InactiveOracle} | nil
  def locate(state, pubkey) do
    case State.get(state, Model.ActiveOracle, pubkey) do
      {:ok, m_oracle} ->
        {m_oracle, Model.ActiveOracle}

      :not_found ->
        case State.get(state, Model.InactiveOracle, pubkey) do
          {:ok, m_oracle} -> {m_oracle, Model.InactiveOracle}
          :not_found -> nil
        end
    end
  end

  @spec oracle_tree!(Db.hash()) :: tuple()
  def oracle_tree!(block_hash) do
    {:value, trees} = :aec_db.find_block_state_partial(block_hash, true, [:oracles])
    :aec_trees.oracles(trees)
  end
end

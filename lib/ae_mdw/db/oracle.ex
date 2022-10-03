defmodule AeMdw.Db.Oracle do
  @moduledoc """
  Cache through operations for active and inactive oracles.
  """
  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db

  require Model

  import AeMdw.Util

  @typep pubkey :: Db.pubkey()
  @typep cache_key :: pubkey() | {pos_integer(), pubkey()}
  @typep state :: State.t()

  @spec locate(state(), pubkey()) ::
          {Model.oracle(), Model.ActiveOracle | Model.InactiveOracle} | nil
  def locate(state, pubkey) do
    map_ok_nil(cache_through_read(state, Model.ActiveOracle, pubkey), &{&1, Model.ActiveOracle}) ||
      map_ok_nil(
        cache_through_read(state, Model.InactiveOracle, pubkey),
        &{&1, Model.InactiveOracle}
      )
  end

  @spec cache_through_read(state(), atom(), cache_key()) :: {:ok, Model.oracle()} | nil
  def cache_through_read(state, table, key) do
    case State.cache_get(state, table, key) do
      {:ok, record} ->
        {:ok, record}

      :not_found ->
        case State.get(state, table, key) do
          {:ok, record} -> {:ok, record}
          :not_found -> nil
        end
    end
  end

  @spec oracle_tree!(Blocks.block_hash()) :: tuple()
  def oracle_tree!(block_hash) do
    block_hash
    |> :aec_db.get_block_state()
    |> :aec_trees.oracles()
  end
end

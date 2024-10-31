defmodule AeMdw.Hyperchain do
  @moduledoc """
    Module for hyperchain related functions.
  """
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model

  @typep state() :: State.t()
  @typep pagination :: Collection.direction_limit()
  @typep range :: {:gen, Range.t()} | {:txi, Range.t()} | nil
  @typep page_cursor() :: Collection.pagination_cursor()
  @typep cursor :: binary()

  @leaders_table Model.HyperchainLeaderAtHeight

  def leaders_for_epoch_at_height(height) do
    {:ok, kb_hash} = :aec_chain_state.get_key_block_hash_at_height(height)
    {_tx_env, _trees} = run_env = :aetx_env.tx_env_and_trees_from_hash(:aetx_transaction, kb_hash)
    {:ok, epoch} = :aec_chain_hc.epoch(run_env)

    {:ok, %{seed: seed, validators: validators, length: length, first: first} = _epoch_info} =
      :aec_chain_hc.epoch_info_for_epoch(run_env, epoch)

    {:ok, seed} =
      case seed do
        :undefined ->
          :aec_consensus_hc.get_entropy_hash(epoch)

        otherwise ->
          {:ok, otherwise}
      end

    {:ok, schedule} = :aec_chain_hc.validator_schedule(run_env, seed, validators, length)

    first
    |> Stream.iterate(fn x -> x + 1 end)
    |> Enum.zip(schedule)
  end

  @spec fetch_leaders(state(), pagination(), range(), cursor()) ::
          {page_cursor(), [term()], page_cursor()}
  def fetch_leaders(state, pagination, scope, cursor) do
    cursor = deserialize_leaders_cursor(cursor)

    fn direction ->
      Collection.stream(state, @leaders_table, direction, scope, cursor)
    end
    |> Collection.paginate(
      pagination,
      &render_leader(state, &1),
      &serialize_leaders_cursor/1
    )
  end

  defp serialize_leaders_cursor(nil) do
    nil
  end

  defp serialize_leaders_cursor(height) do
    height
    |> :erlang.term_to_binary()
    |> Base.encode64()
  end

  defp deserialize_leaders_cursor(nil) do
    nil
  end

  defp deserialize_leaders_cursor(bin) do
    bin
    |> Base.decode64!()
    |> :erlang.binary_to_term()
  end

  defp render_leader(state, leader) do
    state
    |> State.fetch!(@leaders_table, leader)
    |> inspect()
  end
end

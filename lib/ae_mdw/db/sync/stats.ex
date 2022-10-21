defmodule AeMdw.Db.Sync.Stats do
  @moduledoc """
  Update general and per contract stats during the syncing process.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Stats
  alias AeMdw.Util

  require Model

  @typep pubkey :: AeMdw.Node.Db.pubkey()

  @spec update_nft_stats(State.t(), pubkey(), nil | pubkey(), nil | pubkey()) :: State.t()
  def update_nft_stats(state, contract_pk, prev_owner_pk, to_pk) do
    state
    |> increment_collection_nfts(contract_pk, prev_owner_pk)
    |> decrement_collection_owners(contract_pk, prev_owner_pk)
    |> increment_collection_owners(contract_pk, to_pk)
  end

  defp increment_collection_nfts(state, contract_pk, nil),
    do: update_stat_counter(state, Stats.nfts_count_key(contract_pk))

  defp increment_collection_nfts(state, _contract_pk, _prev_owner_pk), do: state

  defp decrement_collection_owners(state, _contract_pk, nil), do: state

  defp decrement_collection_owners(state, contract_pk, prev_owner_pk) do
    case State.next(
           state,
           Model.NftOwnerToken,
           {contract_pk, prev_owner_pk, Util.min_256bit_int()}
         ) do
      {:ok, {^contract_pk, ^prev_owner_pk, _token}} ->
        state

      _new_owner ->
        update_stat_counter(state, Stats.nft_owners_count_key(contract_pk), fn count ->
          max(count - 1, 0)
        end)
    end
  end

  defp increment_collection_owners(state, _contract_pk, nil), do: state

  defp increment_collection_owners(state, contract_pk, to_pk) do
    case State.next(state, Model.NftOwnerToken, {contract_pk, to_pk, Util.min_256bit_int()}) do
      {:ok, {^contract_pk, ^to_pk, _token}} -> state
      _new_owner -> update_stat_counter(state, Stats.nft_owners_count_key(contract_pk))
    end
  end

  defp update_stat_counter(state, key, update_fn \\ &(&1 + 1)) do
    State.update(
      state,
      Model.Stat,
      key,
      fn Model.stat(payload: count) = stat -> Model.stat(stat, payload: update_fn.(count)) end,
      Model.stat(index: key, payload: 0)
    )
  end
end

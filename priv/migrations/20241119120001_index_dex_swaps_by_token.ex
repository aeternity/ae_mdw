defmodule AeMdw.Migrations.IndexDexSwapsByToken do
  @moduledoc """
  Indexes DEX swaps by token.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Dex

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    evt_hash = :aec_hash.blake2b_256_hash("SwapTokens")
    key_boundary = {{evt_hash, 0, 0, 0}, {evt_hash, nil, nil, nil}}

    state
    |> Collection.stream(Model.EvtContractLog, :forward, key_boundary, nil)
    |> Stream.flat_map(fn {_evt_hash, txi, contract_txi, log_idx} ->
      pair_pk = Dex.get_pair_pk(state, contract_txi, txi, log_idx)

      Model.dex_pair(token1_pk: token1_pk, token2_pk: token2_pk) =
        State.fetch!(state, Model.DexPair, pair_pk)

      {:ok, token1_create_txi_idx} = Origin.creation_txi_idx(state, token1_pk)
      {:ok, token2_create_txi_idx} = Origin.creation_txi_idx(state, token2_pk)

      [
        WriteMutation.new(
          Model.DexContractTokenSwap,
          Model.dex_contract_token_swap(
            index: {token1_create_txi_idx, txi, log_idx},
            contract_call_create_txi: contract_txi
          )
        ),
        WriteMutation.new(
          Model.DexContractTokenSwap,
          Model.dex_contract_token_swap(
            index: {token2_create_txi_idx, txi, log_idx},
            contract_call_create_txi: contract_txi
          )
        )
      ]
    end)
    |> Stream.chunk_every(1_000)
    |> Stream.map(fn mutations ->
      _state = State.commit_db(state, mutations)

      length(mutations)
    end)
    |> Enum.sum()
    |> then(&{:ok, &1})
  end
end

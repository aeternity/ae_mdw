defmodule AeMdw.Migrations.StoreDexPairsInDatabase do
  @moduledoc """
  Indexes dex pairs information for later use.

  Avoids the need to use DexCache.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    contract_pk = Contract.dex_factory_pubkey()

    case Origin.tx_index(state, {:contract, contract_pk}) do
      {:ok, create_txi} ->
        run_with_contract(state, create_txi)

      :not_found ->
        {:ok, 0}
    end
  end

  defp run_with_contract(state, create_txi) do
    pair_created_event_hash = :aec_hash.blake2b_256_hash("PairCreated")

    state
    |> Collection.stream(
      Model.ContractLog,
      :forward,
      {{create_txi, 0, 0}, {create_txi, nil, nil}},
      nil
    )
    |> Stream.map(&State.fetch!(state, Model.ContractLog, &1))
    |> Stream.filter(&match?(Model.contract_log(hash: ^pair_created_event_hash), &1))
    |> Stream.filter(fn Model.contract_log(args: [token1_pk, token2_pk, pair_pk]) ->
      State.exists?(state, Model.AexnContract, {:aex9, token1_pk}) and
        State.exists?(state, Model.AexnContract, {:aex9, token2_pk}) and
        match?({:ok, _pair_create_txi}, Origin.tx_index(state, {:contract, pair_pk}))
    end)
    |> Enum.map(fn Model.contract_log(args: [token1_pk, token2_pk, pair_pk]) ->
      Model.aexn_contract(meta_info: {_name, token1_symbol, _dec}) =
        State.fetch!(state, Model.AexnContract, {:aex9, token1_pk})

      Model.aexn_contract(meta_info: {_name, token2_symbol, _dec}) =
        State.fetch!(state, Model.AexnContract, {:aex9, token2_pk})

      pair_create_txi_idx = Origin.tx_index!(state, {:contract, pair_pk})

      [
        WriteMutation.new(
          Model.DexPair,
          Model.dex_pair(index: pair_pk, token1_pk: token1_pk, token2_pk: token2_pk)
        ),
        WriteMutation.new(
          Model.DexTokenSymbol,
          Model.dex_token_symbol(index: token1_symbol, pair_create_txi_idx: pair_create_txi_idx)
        ),
        WriteMutation.new(
          Model.DexTokenSymbol,
          Model.dex_token_symbol(index: token2_symbol, pair_create_txi_idx: pair_create_txi_idx)
        )
      ]
    end)
    |> Enum.chunk_every(1000)
    |> Enum.map(fn mutations ->
      _state = State.commit_db(state, mutations)
      length(mutations)
    end)
    |> Enum.sum()
    |> then(&{:ok, &1})
  end
end

defmodule AeMdw.Migrations.DexEvents do
  # credo:disable-for-this-file
  @moduledoc """
  Index dex events.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Log
  alias AeMdw.Sync.DexCache

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    pair_pubkeys_set =
      if State.next(state, Model.Field, nil) == :none do
        MapSet.new()
      else
        load_pairs()
        |> MapSet.new()
      end

    mutations =
      state
      |> stream_swap_tokens_logs()
      |> Stream.filter(fn {_evt_hash, _txi, contract_txi, _log_idx} ->
        contract_pk = Origin.pubkey!(state, {:contract, contract_txi})

        MapSet.member?(pair_pubkeys_set, contract_pk)
      end)
      |> Stream.map(fn {_evt_hash, txi, contract_txi, idx} ->
        State.fetch!(state, Model.ContractLog, {contract_txi, txi, idx})
      end)
      |> Enum.flat_map(fn Model.contract_log(
                            index: {contract_txi, txi, idx},
                            args: [from, to],
                            data: amounts
                          ) ->
        contract_pk = Origin.pubkey!(state, {:contract, contract_txi})

        swap_tokens_mutations(state, contract_pk, txi, idx, [from, to], amounts)
      end)

    _state = State.commit_db(state, mutations)

    {:ok, length(mutations)}
  end

  defp stream_swap_tokens_logs(state) do
    evt_hash = :aec_hash.blake2b_256_hash("SwapTokens")
    key_boundary = {{evt_hash, 0, 0, 0}, {evt_hash, nil, nil, nil}}

    state
    |> Collection.stream(Model.EvtContractLog, :forward, key_boundary, nil)
  end

  defp load_pairs() do
    [:dex_pairs, :dex_pairs_symbols, :dex_tokens]
    |> Enum.filter(&(:ets.info(&1, :name) == :undefined))
    |> Enum.each(&:ets.new(&1, [:named_table, :set, :public]))

    state = State.new()
    contract_pk = Contract.dex_factory_pubkey()
    pair_created_event_hash = :aec_hash.blake2b_256_hash("PairCreated")

    case Origin.tx_index(state, {:contract, contract_pk}) do
      {:ok, create_txi} ->
        state
        |> Collection.stream(
          Model.ContractLog,
          :forward,
          {{create_txi, 0, 0}, {create_txi, nil, nil}},
          nil
        )
        |> Stream.map(&State.fetch!(state, Model.ContractLog, &1))
        |> Stream.filter(fn Model.contract_log(hash: event_hash) ->
          event_hash == pair_created_event_hash
        end)
        |> Stream.filter(fn Model.contract_log(args: [pair_pk, token1_pk, token2_pk]) ->
          State.exists?(state, Model.AexnContract, {:aex9, token1_pk}) and
            State.exists?(state, Model.AexnContract, {:aex9, token2_pk}) and
            match?({:ok, _pair_create_txi}, Origin.tx_index(state, {:contract, pair_pk}))
        end)
        |> Enum.map(fn Model.contract_log(args: [pair_pk, token1_pk, token2_pk]) ->
          DexCache.add_pair(state, pair_pk, token1_pk, token2_pk)
          pair_pk
        end)

      :not_found ->
        []
    end
  end

  defp swap_tokens_mutations(state, contract_pk, txi, idx, [from, to], amounts) do
    with true <- String.printable?(amounts),
         %{token1: token1_pk} <- DexCache.get_pair(contract_pk),
         {:ok, create_txi} <- Origin.tx_index(state, {:contract, token1_pk}) do
      amounts = amounts |> String.split("|") |> Enum.map(&String.to_integer/1)

      [
        WriteMutation.new(
          Model.DexAccountSwapTokens,
          Model.dex_account_swap_tokens(
            index: {from, create_txi, txi, idx},
            to: to,
            amounts: amounts
          )
        ),
        WriteMutation.new(
          Model.DexContractSwapTokens,
          Model.dex_contract_swap_tokens(index: {create_txi, from, txi, idx})
        )
      ]
    else
      reason ->
        Log.warn(
          "[write_swap_tokens] contract not found #{inspect(contract_pk)}, reason=#{reason}"
        )

        []
    end
  end

  defp swap_tokens_mutations(_state, _pk, _txi, _idx, args, _amounts) do
    Log.warn("[write_swap_tokens] args mismatch #{inspect(args)}")

    []
  end
end

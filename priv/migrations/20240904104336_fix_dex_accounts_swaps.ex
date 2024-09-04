defmodule AeMdw.Migrations.FixDexAccountsSwaps do
  @moduledoc """
  Fix create_txi in swaps
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Contract
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Dex
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

    write_mutations =
      state
      |> stream_swap_tokens_logs()
      |> Stream.map(fn {_evt_hash, txi, contract_txi, idx} ->
        {State.fetch!(state, Model.ContractLog, {contract_txi, txi, idx}),
         Origin.pubkey!(state, {:contract, contract_txi})}
      end)
      |> Stream.filter(fn {Model.contract_log(ext_contract: ext_contract_pk), contract_pk} ->
        MapSet.member?(pair_pubkeys_set, contract_pk) or
          MapSet.member?(pair_pubkeys_set, ext_contract_pk)
      end)
      |> Enum.flat_map(fn {Model.contract_log(
                             index: {contract_txi, txi, idx},
                             args: [from, to],
                             data: amounts
                           ), _contract_pk} ->
        actual_create_txi = Dex.get_create_txi(state, contract_txi, txi, idx)
        swap_tokens_mutations(actual_create_txi, txi, idx, [from, to], amounts)
      end)

    tables_keys =
      Enum.into(
        [
          Model.DexAccountSwapTokens,
          Model.DexContractSwapTokens,
          Model.DexSwapTokens
        ],
        %{},
        fn table_name ->
          {table_name,
           state
           |> Collection.stream(table_name, nil)
           |> Enum.to_list()}
        end
      )

    _state = State.commit_db(state, [DeleteKeysMutation.new(tables_keys)])
    _state = State.commit_db(state, write_mutations)

    {:ok,
     Enum.sum(Enum.map(tables_keys, fn {_table, keys} -> length(keys) end)) +
       length(write_mutations)}
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
        |> Stream.filter(fn Model.contract_log(args: [token1_pk, token2_pk, pair_pk]) ->
          State.exists?(state, Model.AexnContract, {:aex9, token1_pk}) and
            State.exists?(state, Model.AexnContract, {:aex9, token2_pk}) and
            match?({:ok, _pair_create_txi}, Origin.tx_index(state, {:contract, pair_pk}))
        end)
        |> Enum.map(fn Model.contract_log(args: [token1_pk, token2_pk, pair_pk]) ->
          DexCache.add_pair(state, pair_pk, token1_pk, token2_pk)
          pair_pk
        end)

      :not_found ->
        []
    end
  end

  defp swap_tokens_mutations(create_txi, txi, idx, [from, to], amounts) do
    if String.printable?(amounts) do
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
        ),
        WriteMutation.new(
          Model.DexSwapTokens,
          Model.dex_swap_tokens(index: {txi, idx, create_txi})
        )
      ]
    else
      Log.warn("[write_swap_tokens] contract amounts not printable: #{create_txi}")

      []
    end
  end
end

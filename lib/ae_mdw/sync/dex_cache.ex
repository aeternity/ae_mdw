defmodule AeMdw.Sync.DexCache do
  @moduledoc """
  Tracks dex pairs contracts.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Origin
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Sync.SyncingQueue
  alias AeMdw.Txs

  require Model

  @pairs_table :dex_pairs
  @pairs_symbols_table :dex_pairs_symbols
  @tokens_table :dex_tokens

  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @type pair_map :: %{token1: pubkey(), token2: pubkey()}
  @type pair_symbols :: %{token1: String.t(), token2: String.t()}

  @spec load :: :ok
  def load() do
    [@pairs_table, @pairs_symbols_table, @tokens_table]
    |> Enum.filter(&(:ets.info(&1, :name) == :undefined))
    |> Enum.each(&:ets.new(&1, [:named_table, :set, :public]))

    SyncingQueue.push(&do_load/0)
  end

  defp do_load() do
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
        |> Enum.each(fn Model.contract_log(args: [token1_pk, token2_pk, pair_pk]) ->
          add_pair(state, pair_pk, token1_pk, token2_pk)
        end)

      :not_found ->
        :ok
    end
  end

  @spec add_pair(State.t(), pubkey(), pubkey(), pubkey()) :: :ok
  def add_pair(state, contract_pk, token1_pk, token2_pk) do
    with {:ok, Model.aexn_contract(meta_info: {_name, symbol1, _dec})} <-
           State.get(state, Model.AexnContract, {:aex9, token1_pk}),
         {:ok, Model.aexn_contract(meta_info: {_name, symbol2, _dec})} <-
           State.get(state, Model.AexnContract, {:aex9, token2_pk}),
         {:ok, pair_create_txi} <- Origin.tx_index(state, {:contract, contract_pk}) do
      :ets.insert(@tokens_table, {symbol1, pair_create_txi})
      :ets.insert(@pairs_table, {contract_pk, token1_pk, token2_pk})
      :ets.insert(@pairs_symbols_table, {pair_create_txi, symbol1, symbol2})
    end

    :ok
  end

  @spec get_pair(pubkey()) :: pair_map() | nil
  def get_pair(contract_pk) do
    case :ets.lookup(@pairs_table, contract_pk) do
      [] ->
        nil

      [{^contract_pk, token1_pk, token2_pk}] ->
        %{token1: token1_pk, token2: token2_pk}
    end
  end

  @spec get_pair_symbols(pubkey()) :: pair_symbols() | nil
  def get_pair_symbols(create_txi) do
    case :ets.lookup(@pairs_symbols_table, create_txi) do
      [] ->
        nil

      [{^create_txi, token1_symbol, token2_symbol}] ->
        %{token1: token1_symbol, token2: token2_symbol}
    end
  end

  @spec get_token_pair_txi(String.t()) :: {:ok, Txs.txi()} | :not_found
  def get_token_pair_txi(token_symbol) do
    case :ets.lookup(@tokens_table, token_symbol) do
      [] ->
        :not_found

      [{^token_symbol, create_txi}] ->
        {:ok, create_txi}
    end
  end

  @spec get_pairs() :: [pair_map()]
  def get_pairs do
    @pairs_table
    |> :ets.tab2list()
    |> Enum.map(fn {contract_pk, token1, token2} ->
      %{pair: contract_pk, token1: token1, token2: token2}
    end)
  end

  @spec get_pair_contract_pk(pubkey()) :: {:ok, [pubkey()]} | :not_found
  def get_pair_contract_pk(searched_contract_pk) do
    match_spec = [
      {{searched_contract_pk, :_, :_}, [], [:"$_"]},
      {{:_, searched_contract_pk, :_}, [], [:"$_"]},
      {{:_, :_, searched_contract_pk}, [], [:"$_"]}
    ]

    case :ets.select(@pairs_table, match_spec) do
      [] -> :not_found
      list -> {:ok, Enum.map(list, fn {pair_pk, _token1_pk, _token2_pk} -> pair_pk end)}
    end
  end
end

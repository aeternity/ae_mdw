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

  require Model

  @pairs_table :dex_pairs

  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @typep pair_map :: %{pair: pubkey(), token1: pubkey(), token2: pubkey()}

  @spec load :: :ok
  def load() do
    _table = :ets.new(@pairs_table, [:public, :set, :named_table])

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
        |> Enum.each(fn Model.contract_log(args: [pair_pk, token1_pk, token2_pk]) ->
          add_pair(pair_pk, token1_pk, token2_pk)
        end)

      :not_found ->
        :ok
    end
  end

  @spec add_pair(pubkey(), pubkey(), pubkey()) :: :ok
  def add_pair(contract_pk, token1, token2) do
    :ets.insert(@pairs_table, {contract_pk, token1, token2})
    :ok
  end

  @spec get_pair(pubkey()) :: pair_map() | nil
  def get_pair(contract_pk) do
    case :ets.lookup(@pairs_table, contract_pk) do
      [] ->
        nil

      [{contract_pk, token1, token2}] ->
        %{pair: contract_pk, token1: token1, token2: token2}
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
end

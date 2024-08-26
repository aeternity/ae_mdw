defmodule AeMdw.Migrations.Aex9LogsCountReindex do
  @moduledoc """
  Reindex AEx9 logs count.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Stats
  alias AeMdw.Util

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    key_boundary = {
      {:aex9, "", nil},
      {:aex9, Util.max_name_bin(), nil}
    }

    mutations_length =
      state
      |> Collection.stream(Model.AexnContractDowncasedName, :forward, key_boundary, nil)
      |> Stream.flat_map(fn {:aex9, _name, contract_pk} ->
        Model.aexn_contract(txi_idx: {create_txi, _idx}) =
          State.fetch!(state, Model.AexnContract, {:aex9, contract_pk})

        key_boundary = {
          {create_txi, Util.min_int(), nil},
          {create_txi, Util.max_int(), nil}
        }

        count =
          state
          |> Collection.stream(Model.ContractLog, :forward, key_boundary, nil)
          |> Enum.count()

        index = Stats.aex9_logs_count_key(contract_pk)

        if count == 0 do
          []
        else
          case State.get(state, Model.Stat, index) do
            {:ok, Model.stat(payload: ^count)} ->
              []

            _not_found_or_invalid ->
              [WriteMutation.new(Model.Stat, Model.stat(index: index, payload: count))]
          end
        end
      end)
      |> Stream.chunk_every(1000)
      |> Stream.map(fn mutations ->
        _state = State.commit_db(state, mutations)
        length(mutations)
      end)
      |> Enum.sum()

    {:ok, mutations_length}
  end
end

defmodule AeMdw.Migrations.ReindexOldAex141 do
  @moduledoc """
  Rerun indexation for old AEX-141 contracts.
  """

  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Contract

  require Model

  @txi_before_hackaton 30_000_000

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    mutations =
      state
      |> Collection.stream(
        Model.RevOrigin,
        :forward,
        nil,
        {@txi_before_hackaton, nil, <<>>}
      )
      |> Stream.filter(fn {_txi, type, ct_pk} ->
        type == :contract_create_tx and not Database.exists?(Model.AexnContract, {:aex141, ct_pk})
      end)
      |> Enum.map(fn {txi, _type, ct_pk} ->
        Model.tx(block_index: bi) = Database.fetch!(Model.Tx, txi)
        Contract.aexn_create_contract_mutation(ct_pk, bi, txi)
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(fn %{aexn_type: aexn_type} -> aexn_type == :aex141 end)

    _state = State.commit(state, mutations)

    {:ok, length(mutations)}
  end
end

defmodule AeMdw.Migrations.NamesAuctionTimeoutFix do
  @moduledoc """
  Fixes the `auction_timeout` field on ActiveNames.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    active_mutations = names_mutations(state, Model.ActiveName)
    inactive_mutations = names_mutations(state, Model.InactiveName)
    mutations = active_mutations ++ inactive_mutations

    _state = State.commit(state, mutations)

    {:ok, length(mutations)}
  end

  defp names_mutations(state, table) do
    state
    |> Collection.stream(table, nil)
    |> Stream.map(&State.fetch!(state, table, &1))
    |> Enum.map(fn Model.name(claims: [{{last_claim_height, _mbi}, _txi} | _rest], active: active) =
                     name ->
      new_name = Model.name(name, auction_timeout: active - last_claim_height)

      WriteMutation.new(table, new_name)
    end)
  end
end

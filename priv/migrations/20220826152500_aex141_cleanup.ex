defmodule AeMdw.Migrations.Aex141Cleanup do
  @moduledoc """
  Remove old contracts from AEX-141 standard draft.
  """

  alias AeMdw.AexnContracts
  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  import AeMdwWeb.Helpers.AexnHelper, only: [sort_field_truncate: 1]

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    deleted_count =
      state
      |> Collection.stream(Model.AexnContract, {:aex141, <<>>})
      |> Stream.take_while(&match?({:aex141, _pk}, &1))
      |> Stream.map(&Database.fetch!(Model.AexnContract, &1))
      |> Enum.map(fn Model.aexn_contract(
                       index: {:aex141, ct_pk},
                       meta_info: {name, symbol, _baseurl, _type}
                     ) ->
        if AexnContracts.is_aex141?(ct_pk) do
          0
        else
          Database.dirty_delete(Model.AexnContract, {:aex141, ct_pk})

          if not is_atom(name) do
            Database.dirty_delete(
              Model.AexnContractName,
              {:aex141, sort_field_truncate(name), ct_pk}
            )
          end

          if not is_atom(symbol) do
            Database.dirty_delete(
              Model.AexnContractSymbol,
              {:aex141, sort_field_truncate(symbol), ct_pk}
            )
          end

          1
        end
      end)
      |> Enum.sum()

    {:ok, deleted_count}
  end
end

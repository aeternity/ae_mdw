defmodule AeMdw.Migrations.AddNormalizedAexnTables do
  @moduledoc """
  Migration to add normalized AEX-N tables.
  """
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    {name_mutations, name_counts} =
      state
      |> Collection.stream(Model.AexnContractName, nil)
      |> Enum.reduce({[], 0}, fn {type, name, pubkey}, {mutations, counter} ->
        {[
           WriteMutation.new(
             Model.AexnContractDowncasedName,
             Model.aexn_contract_downcased_name(
               index: {type, String.downcase(name), pubkey},
               original_name: name
             )
           )
           | mutations
         ], counter + 1}
      end)

    symbol_mutations =
      state
      |> Collection.stream(Model.AexnContractSymbol, nil)
      |> Enum.map(fn {type, symbol, pubkey} ->
        WriteMutation.new(
          Model.AexnContractDowncasedSymbol,
          Model.aexn_contract_downcased_symbol(
            index: {type, String.downcase(symbol), pubkey},
            original_symbol: symbol
          )
        )
      end)

    State.commit(state, name_mutations ++ symbol_mutations)

    {:ok, name_counts}
  end
end

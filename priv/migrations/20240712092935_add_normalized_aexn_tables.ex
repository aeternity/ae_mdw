defmodule AeMdw.Migrations.AddNormalizedAexnTables do
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    {new_state, name_counts} =
      state
      |> Collection.stream(Model.AexnContractName, nil)
      |> Enum.reduce({state, 0}, fn {type, name, pubkey}, {acc_state, counter} ->
        {State.put(
           acc_state,
           Model.AexnContractDowncasedName,
           Model.aexn_contract_downcased_name(
             index: {type, String.downcase(name), pubkey},
             original_name: name
           )
         ), counter + 1}
      end)

    _new_state =
      state
      |> Collection.stream(Model.AexnContractSymbol, nil)
      |> Enum.reduce(new_state, fn {type, symbol, pubkey}, acc_state ->
        State.put(
          acc_state,
          Model.AexnContractDowncasedSymbol,
          Model.aexn_contract_downcased_symbol(
            index: {type, String.downcase(symbol), pubkey},
            original_symbol: symbol
          )
        )
      end)

    {:ok, name_counts}
  end
end

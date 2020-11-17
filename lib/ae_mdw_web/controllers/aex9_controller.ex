defmodule AeMdwWeb.Aex9Controller do

  use AeMdwWeb, :controller
  use PhoenixSwagger

  alias AeMdw.Db.Model
  alias AeMdwWeb.SwaggerParameters
  require Model

  import AeMdw.Db.Util

  ##########

  def by_names(conn, params),
    do: by_names_reply(conn, prefix_param(params), all_param(params))

  def by_symbols(conn, params),
    do: by_symbols_reply(conn, prefix_param(params), all_param(params))

  ##########

  def by_names_reply(conn, prefix, all?) do
    entries =
      get_keys(Model.Aex9Contract, prefix, all? && :all || :last)
      |> Enum.map(&model_to_json(:aex9_contract, &1))
    json(conn, entries)
  end

  def by_symbols_reply(conn, prefix, all?) do
    entries =
      get_keys(Model.Aex9ContractSymbol, prefix, all? && :all || :last)
      |> Enum.map(&model_to_json(:aex9_contract_symbol, &1))
    json(conn, entries)
  end

  ##########

  def model_to_json(model),
    do: model_to_json(elem(model, 0), elem(model, 1))

  def model_to_json(:aex9_contract, {name, symbol, txi, decimals}) do
    %{name: name,
      symbol: symbol,
      decimals: decimals,
      txi: txi}
  end

  def model_to_json(:aex9_contract_symbol, {symbol, name, txi, decimals}),
    do: model_to_json(:aex9_contract, {name, symbol, txi, decimals})

  def model_to_json(:rev_aex9_contract, {txi, name, symbol, decimals}),
    do: model_to_json(:aex9_contract, {name, symbol, txi, decimals})


  def prefix_param(params), do: Map.get(params, "prefix", "")

  def all_param(%{"all" => x}) when x in [nil, "true", [nil], ["true"]], do: true
  def all_param(%{}), do: false

  ##########


  def get_keys(table, prefix, :all),
    do: get_keys(table, prefix, fn -> [] end, fn _, v, l -> [v | l] end, &Enum.reverse/1)
  def get_keys(table, prefix, :last),
    do: get_keys(table, prefix, &:gb_trees.empty/0, &:gb_trees.enter/3, &:gb_trees.values/1)


  def get_keys(table, prefix, new, add, return) do
    prefix_len = String.length(prefix)
    prefix? = prefix_len == 0
      && fn _ -> true end
      || &(String.length(&1) >= prefix_len && :binary.part(&1, 0, prefix_len) == prefix)
    return.(
      case next(table, {prefix, "", 0, 0}) do
        :"$end_of_table" ->
          new.()
        {s, _, _, _} = start_key ->
          case prefix?.(s) do
            false -> new.()
            true ->
              collect_keys(table, add.(s, start_key, new.()), start_key, &next/2,
                fn {s, _, _, _} = key, acc ->
                  case prefix?.(s) do
                    false -> {:halt, acc}
                    true -> {:cont, add.(s, key, acc)}
                  end
                end)
          end
      end)
  end

  ##########
  # TODO: swagger

  # def swagger_definitions do
  #   %{
  #     Aex9Response:
  #       swagger_schema do
  #         title("Aex9Response")
  #         description("Schema for AEX9 contract")

  #         properties do
  #           name(:string, "The name of AEX9 token", required: true)
  #           symbol(:string, "The symbol of AEX9 token", required: true)
  #           decimals(:integer, "The number of decimals for AEX9 token", required: true)
  #           txi(:integer, "The transaction index of contract create transction", required: true)
  #         end

  #         example(%{
  #               decimals: 18,
  #               name: "testnetAE",
  #               symbol: "TTAE",
  #               txi: 11145713
  #         })
  #       end
  #   }
  # end


end

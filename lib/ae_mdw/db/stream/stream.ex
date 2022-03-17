defmodule AeMdw.Db.Stream do
  alias __MODULE__, as: DBS
  alias AeMdw.Node, as: AE
  alias AeMdw.Db.Model
  alias AeMdw.Validate

  require Model

  import AeMdw.Db.Util
  import AeMdw.Util

  ################################################################################

  def map(scope),
    do: map(scope, &id/1)

  def map(scope, mapper),
    do: map(scope, mapper, nil)

  def map(scope, mapper, query),
    do: map(scope, mapper, query, nil)

  def map(scope, mapper, nil, order) do
    tab = Model.Tx
    fun = DBS.Mapper.function(mapper, tab)
    DBS.Resource.map(scope, tab, fun, nil, order)
  end

  def map(scope, mapper, [], order),
    do: map(scope, mapper, nil, order)

  def map(scope, mapper, [_ | _] = query, order),
    do: map(scope, mapper, query_groups(query), order)

  def map(scope, mapper, %{} = query_groups, order) when map_size(query_groups) == 0,
    do: map(scope, mapper, nil, order)

  def map(scope, mapper, %{} = query_groups, order),
    do: map(scope, mapper, DBS.Query.Parser.parse(query_groups), order)

  def map(scope, mapper, {ids, types}, order) when map_size(ids) == 0 do
    tab = Model.Type
    fun = DBS.Mapper.function(mapper, tab)
    DBS.Resource.map(scope, tab, fun, types, order)
  end

  def map(scope, mapper, {ids, types}, order) when map_size(ids) > 0 do
    case DBS.Query.Planner.plan({ids, types}) do
      nil ->
        Stream.map([], & &1)

      {roots, checks} ->
        {tab, fun} = roots_tab_fun({roots, checks}, mapper)
        DBS.Resource.map(scope, tab, fun, {:roots, MapSet.new(roots)}, order)
    end
  end

  def map(scope, mapper, {:or, [_ | _] = and_queries}, order) do
    {types, or_roots_checks} =
      and_queries
      |> Stream.map(&query_groups/1)
      |> Stream.map(&DBS.Query.Parser.parse/1)
      |> Stream.map(&DBS.Query.Planner.plan/1)
      |> Enum.reduce({MapSet.new(), []}, fn
        nil, acc ->
          acc

        {:type, ts}, {types, or_roots_checks} ->
          {MapSet.union(types, ts), or_roots_checks}

        {roots, checks}, {types, or_roots_checks} ->
          {Model.Field, check_fun} = roots_tab_fun({roots, checks}, mapper)
          {types, [{:roots, MapSet.new(roots), check_fun} | or_roots_checks]}
      end)

    case {Enum.count(types), or_roots_checks} do
      {0, []} ->
        Stream.map([], & &1)

      {_, []} ->
        map(scope, mapper, {%{}, types}, order)

      {_, [{:roots, roots, check_fun}]} ->
        DBS.Resource.map(scope, Model.Field, check_fun, {:roots, roots}, order)

      {_, [_, _ | _]} ->
        DBS.Resource.Or.map(scope, mapper, {types, or_roots_checks}, order)
    end
  end

  ##

  def roots_tab_fun({_roots, checks}, mapper) do
    tab = Model.Field

    fun =
      case map_size(checks) == 0 do
        true ->
          DBS.Mapper.function(mapper, tab)

        false ->
          check_compose(DBS.Mapper.function(mapper, tab), &check(&1, checks))
      end

    {tab, fun}
  end

  def check(model_field, all_checks) do
    {type, model_tx, tx_rec, data} = tx_data(model_field)
    txi = Model.tx(model_tx, :index)
    type_checks = Map.get(all_checks, type, [])

    valid? =
      Enum.reduce_while(type_checks, nil, fn
        {pk_pos, pk_pos_checks}, nil ->
          case check(pk_pos, tx_rec, type, txi) do
            false ->
              {:cont, nil}

            true ->
              check = &check(&1, tx_rec, type, txi)
              {:halt, Enum.all?(pk_pos_checks, check) || nil}
          end
      end)

    valid? && {model_tx, data}
  end

  def check({pk, nil}, _tx_rec, type, txi),
    do: read(Model.RevOrigin, {txi, type, pk}) != []

  def check({pk, pos}, tx_rec, _type, _txi),
    do: Validate.id!(elem(tx_rec, pos)) === pk

  def tx_data(model_field) do
    {type, _pos, _pk, txi} = Model.field(model_field, :index)
    model_tx = read_tx!(txi)
    tx_hash = Model.tx(model_tx, :id)
    {_, _, _, tx_rec} = data = AE.Db.get_tx_data(tx_hash)
    {type, model_tx, tx_rec, data}
  end

  def check_compose(format_fn, check_fn) do
    fn x ->
      case check_fn.(x) do
        nil -> nil
        res -> format_fn.(res)
      end
    end
  end

  def query_groups([_ | _] = query) do
    query
    |> Enum.map(&query_kv/1)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  defp query_kv({:type, v}), do: {"type", to_string(v)}
  defp query_kv({:type_group, v}), do: {"type_group", to_string(v)}
  defp query_kv({k, v}), do: {to_string(k), v}

  ################################################################################
  # examples of queries:

  def t1(),
    do: [
      "spend.sender_id": "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
      recipient_id: "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
      account: "ak_zvU8YQLagjcfng7Tg8yCdiZ1rpiWNp1PBn3vtUs44utSvbJVR",
      contract: "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      type_group: :channel
    ]

  def t2(),
    do: [
      account: "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
      account: "ak_zvU8YQLagjcfng7Tg8yCdiZ1rpiWNp1PBn3vtUs44utSvbJVR"
    ]

  def t3(),
    do: [sender_id: "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR"]

  def t4(),
    do: [contract_id: "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z"]

  def t5(),
    do: [
      account: "ak_zvU8YQLagjcfng7Tg8yCdiZ1rpiWNp1PBn3vtUs44utSvbJVR",
      contract: "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z"
    ]

  def t6(),
    do: [account: "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR"]

  def t7(),
    do: [
      account: "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
      account: "ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS"
    ]

  def t8(),
    do: [
      account: "ak_idkx6m3bgRr7WiKXuB8EBYBoRqVsaSc6qo4dsd23HKgj3qiCF",
      account: "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN"
    ]

  def t9(),
    do: [
      "name_transfer.recipient_id": "ak_idkx6m3bgRr7WiKXuB8EBYBoRqVsaSc6qo4dsd23HKgj3qiCF",
      account: "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN"
    ]

  def t10(),
    do: [
      sender_id: "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
      account: "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN"
    ]

  def t11(),
    do: [
      account: "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
      account: "ak_ozzwBYeatmuN818LjDDDwRSiBSvrqt4WU7WvbGsZGVre72LTS",
      account: "ak_25BWMx4An9mmQJNPSwJisiENek3bAGadze31Eetj4K4JJC8VQN"
    ]

  def t12(),
    do: [
      account: "ak_HzcS4HvhTtiD3KaVXW9umgqCW6dyg3KWgmyxHfir8x9Rads4a",
      contract: "ct_2rtXsV55jftV36BMeR5gtakN2VjcPtZa3PBURvzShSYWEht3Z7"
    ]

  def t13(),
    do: [
      account: "ak_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR",
      type: "oracle_register"
    ]
end

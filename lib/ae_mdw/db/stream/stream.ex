defmodule AeMdw.Db.Stream do
  alias __MODULE__, as: DBS
  alias AeMdw.Db.Model
  alias AeMdw.Validate

  require Model

  import AeMdw.{Util, Db.Util}

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

  def roots_tab_fun({roots, checks}, mapper) do
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
    {_, _, _, tx_rec} = data = tx_rec_data(tx_hash)
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

  # :forward -> {:from, 0}
  # :backward -> {:downto, 0}
  # a..b -> {:txi, a..b}
  #
  # {:txi, 0..last_txi}
  # {:gen, 50..last_gen}
  # {:time, 12343214..last_time}
  #

  # def t() do
  #   # SCOPES
  #   #
  #   # :forward, :backward,
  #   # {:txi, not-found}, {:txi, 1}, {:txi, ...},
  #   # {:gen, not-found}, {:gen, 1}, {:gen, ...},
  #   # {:time, not-found}, {:time, 1}, {:time, ...}
  #   #
  #   # TABLES
  #   #
  #   # :block, :tx, :type, :time, :object

  #   # FORWARD tests
  #   true =
  #     [{0, -1}, {1, -1}, {1, 0}, {2, -1}, {3, -1}, {4, -1}, {5, -1}, {6, -1}, {7, -1}, {8, -1}] ==
  #       :forward |> DBS.map(~t[block], &Model.block(&1, :index)) |> Enum.take(10)

  #   first_10_tx_recs = :forward |> DBS.map(~t[tx]) |> Enum.take(10)
  #   txis = Enum.to_list(0..9)
  #   ^txis = Enum.map(first_10_tx_recs, &tx_txi/1)

  #   true =
  #     Enum.map(txis, &{:type, {:spend_tx, &1}, nil}) ==
  #       :forward |> DBS.map(~t[type]) |> Enum.take(10)

  #   true =
  #     Enum.map(first_10_tx_recs, &{:time, {Model.tx(&1, :time), Model.tx(&1, :index)}, nil}) ==
  #       :forward |> DBS.map(~t[time]) |> Enum.take(10)

  #   genesis_pk =
  #     <<144, 125, 123, 13, 183, 6, 234, 74, 192, 116, 177, 35, 130, 58, 45, 133, 185, 14, 29, 143,
  #       113, 100, 77, 100, 127, 133, 98, 225, 46, 110, 14, 75>>

  #   # BACKWARD tests
  #   10 = :backward |> DBS.map(~t[block]) |> Enum.take(10) |> Enum.count()
  #   [{_, -1} | _] = :backward |> DBS.map(~t[block], &Model.block(&1, :index)) |> Enum.take(5)
  #   last_10_txis = :backward |> DBS.map(~t[tx], :txi) |> Enum.take(10)
  #   10 = Enum.count(last_10_txis)
  #   ^last_10_txis = Enum.reverse(Enum.sort(Enum.uniq(last_10_txis)))
  #   ^last_10_txis = :backward |> DBS.map(~t[type], :txi) |> Enum.take(10)
  #   ^last_10_txis = :backward |> DBS.map(~t[time], :txi) |> Enum.take(10)

  #   # GEN tests
  #   [{1, -1}, {1, 0}] =
  #     {:gen, 1} |> DBS.map(~t[block], &Model.block(&1, :index)) |> Enum.to_list()

  #   [] = {:gen, 10_000} |> DBS.map(~t[tx]) |> Enum.take(10)
  #   txis = [77022, 77023, 77024, 77025]
  #   scope = {:gen, 10_000..10_100}
  #   ^txis = scope |> DBS.map(~t[tx], &Model.tx(&1, :index)) |> Enum.take(10)
  #   ^txis = scope |> DBS.map(~t[type], &elem(Model.type(&1, :index), 1)) |> Enum.take(10)
  #   ^txis = scope |> DBS.map(~t[time], &elem(Model.time(&1, :index), 1)) |> Enum.take(10)
  #   blocks = scope |> DBS.map(~t[block], &Model.block(&1, :index)) |> Enum.to_list()
  #   {10000, -1} = hd(blocks)
  #   {10100, -1} = List.last(blocks)

  #   # TIME tests
  #   scope = {:time, 1_545_163_941_077..1_545_168_969_077}
  #   txis = [77026, 77027, 77028, 77029, 77030, 77031]
  #   ^txis = scope |> DBS.map(~t[type], &elem(Model.type(&1, :index), 1)) |> Enum.take(10)
  #   ^txis = scope |> DBS.map(~t[time], &elem(Model.time(&1, :index), 1)) |> Enum.take(10)
  #   ^txis = scope |> DBS.map(~t[tx], &Model.tx(&1, :index)) |> Enum.take(10)
  #   blocks = scope |> DBS.map(~t[block], &Model.block(&1, :index)) |> Enum.to_list()
  #   {10111, 0} = hd(blocks)
  #   {10132, 0} = List.last(blocks)

  #   # TYPE tests
  #   txis = Enum.to_list(3_000_000..3_000_009)

  #   ^txis =
  #     {:txi, 3_000_000..4_000_000}
  #     |> DBS.map(~t[type], &elem(Model.type(&1, :index), 1))
  #     |> Enum.take(10)

  #   ^txis =
  #     {:time, 1_567_585_929_155..1_567_585_949_232}
  #     |> DBS.map(~t[type], &elem(Model.type(&1, :index), 1))
  #     |> Enum.take(20)

  #   all_txis =
  #     {:gen, 134_252..134_253}
  #     |> DBS.map(~t[type], &elem(Model.type(&1, :index), 1))
  #     |> Enum.to_list()

  #   true = MapSet.subset?(MapSet.new(txis), MapSet.new(all_txis))

  #   # TXI tests
  #   [123_456] = {:txi, 123_456} |> DBS.map(~t[tx], :txi) |> Enum.take(10)

  #   true =
  #     Enum.to_list(10_000..10_009) ==
  #       {:txi, 10_000..10_009} |> DBS.map(~t[tx], :txi) |> Enum.take(100)

  #   true =
  #     Enum.to_list(10_009..10_000) ==
  #       {:txi, 10_009..10_000} |> DBS.map(~t[tx], :txi) |> Enum.take(100)

  #   # # OBJECT tests
  #   # pk =
  #   #   <<140, 45, 15, 171, 198, 112, 76, 122, 188, 218, 79, 0, 14, 175, 238, 64, 9, 82, 93, 44,
  #   #     169, 176, 237, 27, 115, 221, 101, 211, 5, 168, 169, 235>>

  #   # obj_recs =
  #   #   {:txi, 250_000..500_000}
  #   #   |> DBS.map(~t[object], & &1, {pk, AE.tx_group(:name)})
  #   #   |> Enum.to_list()

  #   # true = Enum.all?(obj_recs, &(elem(Model.object(&1, :index), 0) == :name_preclaim_tx))
  #   # true = Enum.all?(obj_recs, &(elem(Model.object(&1, :index), 1) == pk))

  #   # ^obj_recs =
  #   #   {:time, 1_546_835_654_149..1_548_764_956_779}
  #   #   |> DBS.map(~t[object], & &1, {pk, AE.tx_group(:name)})
  #   #   |> Enum.to_list()

  #   # ^obj_recs =
  #   #   {:gen, 19378..30049} |> DBS.map(~t[object], & &1, {pk, AE.tx_group(:name)}) |> Enum.take(10)

  #   :ok
  # end
end

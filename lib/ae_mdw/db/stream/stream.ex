defmodule AeMdw.Db.Stream do
  alias __MODULE__, as: DBS
  alias AeMdw.Db.Model
  alias AeMdw.Node, as: AE

  require Model

  import AeMdw.{Sigil, Util, Db.Util}

  ################################################################################
  # :forward -> {:from, 0}
  # :backward -> {:downto, 0}
  # a..b -> {:txi, a..b}
  #
  # {:txi, 0..last_txi}
  # {:gen, 50..last_gen}
  # {:time, 12343214..last_time}
  #

  def map(scope, tab),
    do: map(scope, tab, &id/1)

  def map(scope, tab, mapper),
    do: map(scope, tab, mapper, nil)

  def map(scope, tab, mapper, query),
    do: map(scope, tab, mapper, query, nil)

  def map(scope, tab, mapper, query, order),
    do: __MODULE__.Resource.map(scope, tab, final_mapper(mapper, tab), query, order)

  ##########

  defp final_mapper(:txi, table), do: to_txi(table)
  defp final_mapper(:json, Model.Tx), do: &Model.tx_to_map/1
  defp final_mapper(:json, Model.Block), do: &Model.block_to_map/1
  defp final_mapper(:json, table), do: compose(&Model.tx_to_map/1, to_tx(table))
  defp final_mapper(:raw, Model.Tx), do: &Model.tx_to_raw_map/1
  defp final_mapper(:raw, Model.Block), do: &Model.block_to_raw_map/1
  defp final_mapper(:raw, table), do: compose(&Model.tx_to_raw_map/1, to_tx(table))
  defp final_mapper({:tx, f}, Model.Tx) when is_function(f, 1), do: f
  defp final_mapper({:tx, f}, table) when is_function(f, 1), do: compose(f, to_tx(table))
  defp final_mapper({:raw, f}, Model.Tx) when is_function(f, 1),
    do: compose(f, &Model.tx_to_raw_map/1)
  defp final_mapper({:raw, f}, table) when is_function(f, 1),
    do: compose(f, &Model.tx_to_raw_map/1, to_tx(table))
  defp final_mapper({:json, f}, Model.Tx) when is_function(f, 1),
    do: compose(f, &Model.tx_to_map/1)
  defp final_mapper({:json, f}, table) when is_function(f, 1),
    do: compose(f, &Model.tx_to_map/1, to_tx(table))
  defp final_mapper(f, _table) when is_function(f, 1), do: f

  def to_tx(Model.Tx), do: &id/1
  def to_tx(table), do: compose(&read_tx!/1, to_txi(table))

  def to_txi(Model.Tx), do: &tx_txi/1
  def to_txi(Model.Type), do: &type_txi/1
  def to_txi(Model.Time), do: &time_txi/1
  def to_txi(Model.Object), do: &object_txi/1

  def tx_txi({:tx, txi, _hash, {_kb_index, _mb_index}, _time}), do: txi
  def type_txi({:type, {_type, txi}, nil}), do: txi
  def time_txi({:time, {_time, txi}, nil}), do: txi
  def object_txi({:object, {_type, _pk, txi}, _, _}), do: txi

  ################################################################################

  def t() do
    # SCOPES
    #
    # :forward, :backward,
    # {:txi, not-found}, {:txi, 1}, {:txi, ...},
    # {:gen, not-found}, {:gen, 1}, {:gen, ...},
    # {:time, not-found}, {:time, 1}, {:time, ...}
    #
    # TABLES
    #
    # :block, :tx, :type, :time, :object

    # FORWARD tests
    true =
      [{0, -1}, {1, -1}, {1, 0}, {2, -1}, {3, -1},
       {4, -1}, {5, -1}, {6, -1}, {7, -1}, {8, -1}] ==
      :forward |> DBS.map(~t[block], &Model.block(&1, :index)) |> Enum.take(10)

    first_10_tx_recs = :forward |> DBS.map(~t[tx]) |> Enum.take(10)
    txis = Enum.to_list(0..9)
    ^txis = Enum.map(first_10_tx_recs, &tx_txi/1)

    true =
      Enum.map(txis, &{:type, {:spend_tx, &1}, nil}) ==
        :forward |> DBS.map(~t[type]) |> Enum.take(10)

    true =
      Enum.map(first_10_tx_recs, &{:time, {Model.tx(&1, :time), Model.tx(&1, :index)}, nil}) ==
        :forward |> DBS.map(~t[time]) |> Enum.take(10)

    genesis_pk =
      <<144, 125, 123, 13, 183, 6, 234, 74, 192, 116, 177, 35, 130, 58, 45, 133, 185, 14, 29, 143,
        113, 100, 77, 100, 127, 133, 98, 225, 46, 110, 14, 75>>

    ^txis = :forward |> DBS.map(~t[object], &object_txi/1, genesis_pk) |> Enum.take(10)
    ^txis = :forward |> DBS.map(~t[object], :txi, genesis_pk) |> Enum.take(10)

    # BACKWARD tests
    10 = :backward |> DBS.map(~t[block]) |> Enum.take(10) |> Enum.count()
    [{_, -1} | _] = :backward |> DBS.map(~t[block], &Model.block(&1, :index)) |> Enum.take(5)
    last_10_txis = :backward |> DBS.map(~t[tx], :txi) |> Enum.take(10)
    10 = Enum.count(last_10_txis)
    ^last_10_txis = Enum.reverse(Enum.sort(Enum.uniq(last_10_txis)))
    ^last_10_txis = :backward |> DBS.map(~t[type], :txi) |> Enum.take(10)
    ^last_10_txis = :backward |> DBS.map(~t[time], :txi) |> Enum.take(10)
    last_10_object_txis = :backward |> DBS.map(~t[object], :txi, genesis_pk) |> Enum.take(10)
    10 = Enum.count(last_10_object_txis)
    ^last_10_object_txis = Enum.reverse(Enum.sort(Enum.uniq(last_10_object_txis)))

    # GEN tests
    [{1, -1}, {1, 0}] =
      {:gen, 1} |> DBS.map(~t[block], &Model.block(&1, :index)) |> Enum.to_list()

    [] = {:gen, 10_000} |> DBS.map(~t[tx]) |> Enum.take(10)
    txis = [77022, 77023, 77024, 77025]
    scope = {:gen, 10_000..10_100}
    ^txis = scope |> DBS.map(~t[tx], &Model.tx(&1, :index)) |> Enum.take(10)
    ^txis = scope |> DBS.map(~t[type], &elem(Model.type(&1, :index), 1)) |> Enum.take(10)
    ^txis = scope |> DBS.map(~t[time], &elem(Model.time(&1, :index), 1)) |> Enum.take(10)
    blocks = scope |> DBS.map(~t[block], &Model.block(&1, :index)) |> Enum.to_list()
    {10000, -1} = hd(blocks)
    {10100, -1} = List.last(blocks)

    # TIME tests
    scope = {:time, 1_545_163_941_077..1_545_168_969_077}
    txis = [77026, 77027, 77028, 77029, 77030, 77031]
    ^txis = scope |> DBS.map(~t[type], &elem(Model.type(&1, :index), 1)) |> Enum.take(10)
    ^txis = scope |> DBS.map(~t[time], &elem(Model.time(&1, :index), 1)) |> Enum.take(10)
    ^txis = scope |> DBS.map(~t[tx], &Model.tx(&1, :index)) |> Enum.take(10)
    blocks = scope |> DBS.map(~t[block], &Model.block(&1, :index)) |> Enum.to_list()
    {10111, 0} = hd(blocks)
    {10132, 0} = List.last(blocks)

    # TYPE tests
    txis = Enum.to_list(3_000_000..3_000_009)

    ^txis =
      {:txi, 3_000_000..4_000_000}
      |> DBS.map(~t[type], &elem(Model.type(&1, :index), 1))
      |> Enum.take(10)

    ^txis =
      {:time, 1_567_585_929_155..1_567_585_949_232}
      |> DBS.map(~t[type], &elem(Model.type(&1, :index), 1))
      |> Enum.take(20)

    all_txis =
      {:gen, 134_252..134_253}
      |> DBS.map(~t[type], &elem(Model.type(&1, :index), 1))
      |> Enum.to_list()

    true = MapSet.subset?(MapSet.new(txis), MapSet.new(all_txis))

    # TXI tests
    [123_456] = {:txi, 123_456} |> DBS.map(~t[tx], :txi) |> Enum.take(10)

    true =
      Enum.to_list(10_000..10_009) ==
        {:txi, 10_000..10_009} |> DBS.map(~t[tx], :txi) |> Enum.take(100)

    true =
      Enum.to_list(10_009..10_000) ==
        {:txi, 10_009..10_000} |> DBS.map(~t[tx], :txi) |> Enum.take(100)

    # OBJECT tests
    pk =
      <<140, 45, 15, 171, 198, 112, 76, 122, 188, 218, 79, 0, 14, 175, 238, 64, 9, 82, 93, 44,
        169, 176, 237, 27, 115, 221, 101, 211, 5, 168, 169, 235>>

    obj_recs =
      {:txi, 250_000..500_000}
      |> DBS.map(~t[object], & &1, {pk, AE.tx_group(:name)})
      |> Enum.to_list()

    true = Enum.all?(obj_recs, &(elem(Model.object(&1, :index), 0) == :name_preclaim_tx))
    true = Enum.all?(obj_recs, &(elem(Model.object(&1, :index), 1) == pk))

    ^obj_recs =
      {:time, 1_546_835_654_149..1_548_764_956_779}
      |> DBS.map(~t[object], & &1, {pk, AE.tx_group(:name)})
      |> Enum.to_list()

    ^obj_recs =
      {:gen, 19378..30049} |> DBS.map(~t[object], & &1, {pk, AE.tx_group(:name)}) |> Enum.take(10)

    :ok
  end
end

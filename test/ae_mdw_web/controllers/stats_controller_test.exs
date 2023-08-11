defmodule AeMdwWeb.StatsControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store

  require Model

  @ms_per_day 24 * 3_600 * 1_000
  @ms_per_week @ms_per_day * 7

  describe "total_stats" do
    test "it includes last_tx_hash", %{conn: conn, store: store} do
      tx_hash = <<0::256>>
      encoded_tx_hash = Enc.encode(:tx_hash, tx_hash)

      store =
        store
        |> Store.put(Model.DeltaStat, Model.delta_stat(index: 1))
        |> Store.put(Model.TotalStat, Model.total_stat(index: 1))
        |> Store.put(Model.Tx, Model.tx(index: 0, id: tx_hash))
        |> Store.put(Model.Block, Model.block(index: {1, -1}, tx_index: 1))

      assert %{"prev" => nil, "data" => [stat1], "next" => nil} =
               conn
               |> with_store(store)
               |> get("/v2/totalstats")
               |> json_response(200)

      assert %{
               "last_tx_hash" => ^encoded_tx_hash
             } = stat1
    end

    test "if no gens synced yet, it returns empty results", %{conn: conn, store: store} do
      assert %{"prev" => nil, "data" => [], "next" => nil} =
               conn
               |> with_store(store)
               |> get("/v2/totalstats")
               |> json_response(200)
    end
  end

  describe "delta_stats" do
    test "it includes last_tx_hash", %{conn: conn, store: store} do
      tx_hash = <<0::256>>
      encoded_tx_hash = Enc.encode(:tx_hash, tx_hash)

      store =
        store
        |> Store.put(Model.DeltaStat, Model.delta_stat(index: 1))
        |> Store.put(Model.Tx, Model.tx(index: 0, id: tx_hash))
        |> Store.put(Model.Block, Model.block(index: {1, -1}, tx_index: 1))

      assert %{"prev" => nil, "data" => [stat1], "next" => nil} =
               conn
               |> with_store(store)
               |> get("/v2/deltastats")
               |> json_response(200)

      assert %{
               "last_tx_hash" => ^encoded_tx_hash
             } = stat1
    end

    test "if no gens synced yet, it returns empty results", %{conn: conn, store: store} do
      assert %{"prev" => nil, "data" => [], "next" => nil} =
               conn
               |> with_store(store)
               |> get("/v2/deltastats")
               |> json_response(200)
    end
  end

  describe "transactions_statistics" do
    test "it returns the count of transactions for the latest daily periods", %{
      conn: conn,
      store: store
    } do
      start_interval1 = 1_000
      start_interval2 = 2_000
      start_interval3 = 3_000
      st1_index = {{:transactions, :all}, :day, start_interval1}
      st2_index = {{:transactions, :all}, :day, start_interval2}
      st3_index = {{:transactions, :all}, :day, start_interval3}
      start_time1 = start_interval1 * @ms_per_day
      start_time2 = start_interval2 * @ms_per_day
      start_time3 = start_interval3 * @ms_per_day

      store =
        store
        |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 3))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/statistics/transactions", limit: 2)
               |> json_response(200)

      assert %{"start_date" => ^start_time3, "count" => 3} = st1
      assert %{"start_date" => ^start_time2, "count" => 5} = st2

      assert %{"prev" => prev_url, "data" => [st3]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => ^start_time1, "count" => 1} = st3

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "it returns the count of transactions filtered by a tx type", %{conn: conn, store: store} do
      unused_start_interval = 500
      start_interval1 = 1_000
      start_interval2 = 2_000
      start_interval3 = 3_000
      start_time1 = start_interval1 * @ms_per_day
      start_time2 = start_interval2 * @ms_per_day
      start_time3 = start_interval3 * @ms_per_day
      st1_index = {{:transactions, :all}, :day, unused_start_interval}
      st2_index = {{:transactions, :oracle_register_tx}, :day, unused_start_interval}
      st3_index = {{:transactions, :spend_tx}, :day, start_interval1}
      st4_index = {{:transactions, :spend_tx}, :day, start_interval2}
      st5_index = {{:transactions, :spend_tx}, :day, start_interval3}

      store =
        store
        |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st4_index, count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: st5_index, count: 3))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/statistics/transactions",
                 limit: 2,
                 tx_type: "spend",
                 direction: "forward"
               )
               |> json_response(200)

      assert %{"start_date" => ^start_time1, "count" => 1} = st1
      assert %{"start_date" => ^start_time2, "count" => 5} = st2

      assert %{"prev" => prev_url, "data" => [st3]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => ^start_time3, "count" => 3} = st3

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end
  end

  test "when interval_by = week, it returns the count of transactions for the latest weekly periods",
       %{
         conn: conn,
         store: store
       } do
    start_interval1 = 0
    start_interval2 = 1_000
    start_interval3 = 2_000
    st1_index = {{:transactions, :all}, :week, start_interval1}
    st2_index = {{:transactions, :all}, :week, start_interval2}
    st3_index = {{:transactions, :all}, :week, start_interval3}
    start_time1 = start_interval1 * @ms_per_week
    start_time2 = start_interval2 * @ms_per_week
    start_time3 = start_interval3 * @ms_per_week

    store =
      store
      |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
      |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 5))
      |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 3))

    conn = with_store(conn, store)

    assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
             conn
             |> get("/v3/statistics/transactions", limit: 2, interval_by: "week")
             |> json_response(200)

    assert %{"start_date" => ^start_time3, "count" => 3} = st1
    assert %{"start_date" => ^start_time2, "count" => 5} = st2

    assert %{"prev" => prev_url, "data" => [st3]} =
             conn
             |> get(next_url)
             |> json_response(200)

    assert %{"start_date" => ^start_time1, "count" => 1} = st3

    assert %{"data" => ^statistics} =
             conn
             |> get(prev_url)
             |> json_response(200)
  end

  test "when interval_by = month, it returns the count of transactions for the latest monthly periods",
       %{
         conn: conn,
         store: store
       } do
    start_interval1 = 0
    start_interval2 = 12
    start_interval3 = 24
    start_interval4 = 36
    st1_index = {{:transactions, :all}, :month, start_interval1}
    st2_index = {{:transactions, :all}, :month, start_interval2}
    st3_index = {{:transactions, :all}, :month, start_interval3}
    st4_index = {{:transactions, :all}, :month, start_interval4}
    {:ok, start_date1, _offset} = DateTime.from_iso8601("1970-01-01T00:00:00Z")
    {:ok, start_date2, _offset} = DateTime.from_iso8601("1971-01-01T00:00:00Z")
    {:ok, start_date3, _offset} = DateTime.from_iso8601("1972-01-01T00:00:00Z")
    {:ok, start_date4, _offset} = DateTime.from_iso8601("1973-01-01T00:00:00Z")
    start_time1 = DateTime.to_unix(start_date1) * 1_000
    start_time2 = DateTime.to_unix(start_date2) * 1_000
    start_time3 = DateTime.to_unix(start_date3) * 1_000
    start_time4 = DateTime.to_unix(start_date4) * 1_000

    store =
      store
      |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
      |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 5))
      |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 3))
      |> Store.put(Model.Statistic, Model.statistic(index: st4_index, count: 8))

    conn = with_store(conn, store)

    assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
             conn
             |> get("/v3/statistics/transactions", limit: 2, interval_by: "month")
             |> json_response(200)

    assert %{"start_date" => ^start_time4, "count" => 8} = st1
    assert %{"start_date" => ^start_time3, "count" => 3} = st2

    assert %{"prev" => prev_url, "data" => [st3, st4]} =
             conn
             |> get(next_url)
             |> json_response(200)

    assert %{"start_date" => ^start_time2, "count" => 5} = st3
    assert %{"start_date" => ^start_time1, "count" => 1} = st4

    assert %{"data" => ^statistics} =
             conn
             |> get(prev_url)
             |> json_response(200)
  end
end

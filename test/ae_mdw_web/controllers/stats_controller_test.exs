defmodule AeMdwWeb.StatsControllerTest do
  alias AeMdw.Stats
  use AeMdwWeb.ConnCase, async: false
  import Mock

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Collection

  require Model

  @milliseconds_per_day 24 * 3_600 * 1_000

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
               |> get("/v3/stats/delta")
               |> json_response(200)

      assert %{
               "last_tx_hash" => ^encoded_tx_hash
             } = stat1
    end

    test "if no gens synced yet, it returns empty results", %{conn: conn, store: store} do
      assert %{"prev" => nil, "data" => [], "next" => nil} =
               conn
               |> with_store(store)
               |> get("/v3/stats/delta")
               |> json_response(200)
    end
  end

  describe "total_accounts_stats" do
    test "it returns total_accounts stats", %{conn: conn, store: store} do
      store =
        store
        |> Store.put(
          Model.Statistic,
          Model.statistic(index: {:total_accounts, :week, 15_552}, count: 1)
        )

      assert %{"prev" => nil, "data" => [stat1], "next" => nil} =
               conn
               |> with_store(store)
               |> get("/v3/stats/total-accounts")
               |> json_response(200)

      assert %{
               "count" => 0,
               "start_date" => "2018-12-11",
               "end_date" => "2018-12-12"
             } = stat1
    end
  end

  describe "active_accounts_stats" do
    test "it returns active accounts stats", %{conn: conn, store: store} do
      store =
        store
        |> Store.put(
          Model.Statistic,
          Model.statistic(index: {:active_accounts, :week, 15_552}, count: 1)
        )

      assert %{"prev" => nil, "data" => [stat1], "next" => nil} =
               conn
               |> with_store(store)
               |> get("/v3/stats/active-accounts")
               |> json_response(200)

      assert %{
               "count" => 0,
               "start_date" => "2018-12-11",
               "end_date" => "2018-12-12"
             } = stat1
    end
  end

  describe "transactions_stats" do
    test "it returns the count of transactions for the latest daily periods", %{
      conn: conn,
      store: store
    } do
      {network_start_time, network_end_time} = network_time_interval()

      total_indexfn = fn interval_start ->
        {{:total_transactions, :all}, :day, interval_start}
      end

      indexfn = fn interval_start -> {{:transactions, :all}, :day, interval_start} end

      store =
        store
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))
        |> Store.put(Model.Statistic, Model.statistic(index: indexfn.(29), count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: indexfn.(30), count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: indexfn.(31), count: 3))
        |> Store.put(Model.Statistic, Model.statistic(index: total_indexfn.(29), count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: total_indexfn.(30), count: 6))
        |> Store.put(Model.Statistic, Model.statistic(index: total_indexfn.(31), count: 9))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/transactions", limit: 2)
               |> json_response(200)

      assert %{"start_date" => "1970-02-01", "count" => 3} = st1
      assert %{"start_date" => "1970-01-31", "count" => 5} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-01-30", "count" => 1} = st3
      assert %{"start_date" => "1970-01-29", "count" => 0} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)

      assert 9 ==
               conn
               |> get("/v3/stats/transactions/total")
               |> json_response(200)

      assert 8 ==
               conn
               |> get("/v3/stats/transactions/total", min_start_date: "1970-01-31")
               |> json_response(200)

      assert 6 ==
               conn
               |> get("/v3/stats/transactions/total", max_start_date: "1970-01-31")
               |> json_response(200)

      assert 5 ==
               conn
               |> get("/v3/stats/transactions/total",
                 min_start_date: "1970-01-31",
                 max_start_date: "1970-01-31"
               )
               |> json_response(200)
    end

    test "it returns the count of transactions filtered by a tx type", %{conn: conn, store: store} do
      {network_start_time, network_end_time} = network_time_interval()

      indexfn = fn tx_type, interval_start ->
        {{:transactions, tx_type}, :day, interval_start}
      end

      total_indexfn = fn tx_type, interval_start ->
        {{:total_transactions, tx_type}, :day, interval_start}
      end

      store =
        store
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))
        |> Store.put(Model.Statistic, Model.statistic(index: indexfn.(:all, 0), count: 2))
        |> Store.put(
          Model.Statistic,
          Model.statistic(index: indexfn.(:oracle_register_tx, 0), count: 1)
        )
        |> Store.put(Model.Statistic, Model.statistic(index: indexfn.(:spend_tx, 0), count: 1))
        |> Store.put(
          Model.Statistic,
          Model.statistic(index: total_indexfn.(:all, 0), count: 2)
        )
        |> Store.put(
          Model.Statistic,
          Model.statistic(index: total_indexfn.(:oracle_register_tx, 0), count: 1)
        )
        |> Store.put(
          Model.Statistic,
          Model.statistic(index: total_indexfn.(:spend_tx, 0), count: 1)
        )
        |> Store.put(Model.Statistic, Model.statistic(index: indexfn.(:all, 1), count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: indexfn.(:spend_tx, 1), count: 5))
        |> Store.put(
          Model.Statistic,
          Model.statistic(index: total_indexfn.(:all, 1), count: 7)
        )
        |> Store.put(
          Model.Statistic,
          Model.statistic(index: total_indexfn.(:spend_tx, 1), count: 6)
        )
        |> Store.put(Model.Statistic, Model.statistic(index: indexfn.(:all, 3), count: 3))
        |> Store.put(Model.Statistic, Model.statistic(index: indexfn.(:spend_tx, 3), count: 3))
        |> Store.put(
          Model.Statistic,
          Model.statistic(index: total_indexfn.(:all, 3), count: 10)
        )
        |> Store.put(
          Model.Statistic,
          Model.statistic(index: total_indexfn.(:spend_tx, 3), count: 9)
        )

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/transactions",
                 limit: 2,
                 tx_type: "spend",
                 direction: "forward"
               )
               |> json_response(200)

      assert %{"start_date" => "1970-01-01", "count" => 1} = st1
      assert %{"start_date" => "1970-01-02", "count" => 5} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-01-03", "count" => 0} = st3
      assert %{"start_date" => "1970-01-04", "count" => 3} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)

      assert 10 ==
               conn
               |> get("/v3/stats/transactions/total")
               |> json_response(200)

      assert 9 ==
               conn
               |> get("/v3/stats/transactions/total", tx_type: "spend")
               |> json_response(200)

      assert 6 ==
               conn
               |> get("/v3/stats/transactions/total",
                 tx_type: "spend",
                 max_start_date: "1970-01-02"
               )
               |> json_response(200)

      assert 8 ==
               conn
               |> get("/v3/stats/transactions/total",
                 tx_type: "spend",
                 min_start_date: "1970-01-02"
               )
               |> json_response(200)

      assert 5 ==
               conn
               |> get("/v3/stats/transactions/total",
                 tx_type: "spend",
                 min_start_date: "1970-01-02",
                 max_start_date: "1970-01-03"
               )
               |> json_response(200)

      assert 1 ==
               conn
               |> get("/v3/stats/transactions/total", tx_type: "oracle_register")
               |> json_response(200)
    end

    test "when interval_by = week, it returns the count of transactions for the latest weekly periods",
         %{
           conn: conn,
           store: store
         } do
      indexfn = fn interval_by, interval_start ->
        {{:transactions, :all}, interval_by, interval_start}
      end

      total_indexfn = fn interval_start ->
        {{:total_transactions, :all}, :day, interval_start}
      end

      {network_start_time, network_end_time} = network_time_interval()

      store =
        store
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))
        |> Store.put(Model.Statistic, Model.statistic(index: indexfn.(:week, 2), count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: indexfn.(:week, 3), count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: indexfn.(:week, 4), count: 3))
        |> Store.put(Model.Statistic, Model.statistic(index: indexfn.(:day, 1), count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: indexfn.(:day, 7), count: 3))
        |> Store.put(Model.Statistic, Model.statistic(index: indexfn.(:day, 14), count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: total_indexfn.(1), count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: total_indexfn.(7), count: 4))
        |> Store.put(Model.Statistic, Model.statistic(index: total_indexfn.(14), count: 9))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/transactions", limit: 2, interval_by: "week")
               |> json_response(200)

      assert %{"start_date" => "1970-01-29", "count" => 3} = st1
      assert %{"start_date" => "1970-01-22", "count" => 5} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-01-15", "count" => 1} = st3
      assert %{"start_date" => "1970-01-08", "count" => 0} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)

      assert 9 ==
               conn
               |> get("/v3/stats/transactions/total")
               |> json_response(200)

      assert 4 ==
               conn
               |> get("/v3/stats/transactions/total", max_start_date: "1970-01-08")
               |> json_response(200)

      assert 3 ==
               conn
               |> get("/v3/stats/transactions/total",
                 max_start_date: "1970-01-08",
                 min_start_date: "1970-01-08"
               )
               |> json_response(200)

      assert 5 ==
               conn
               |> get("/v3/stats/transactions/total", min_start_date: "1970-01-11")
               |> json_response(200)
    end

    test "when interval_by = month, it returns the count of transactions for the latest monthly periods",
         %{
           conn: conn,
           store: store
         } do
      st1_index = {{:transactions, :all}, :month, 0}
      st2_index = {{:transactions, :all}, :month, 2}
      st3_index = {{:transactions, :all}, :month, 3}
      st4_index = {{:transactions, :all}, :month, 4}
      {network_start_time, network_end_time} = network_time_interval()
      network_end_time = network_end_time + 100 * @milliseconds_per_day

      store =
        store
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))
        |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 3))
        |> Store.put(Model.Statistic, Model.statistic(index: st4_index, count: 8))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/transactions", limit: 2, interval_by: "month")
               |> json_response(200)

      assert %{"start_date" => "1970-05-01", "count" => 8} = st1
      assert %{"start_date" => "1970-04-01", "count" => 3} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-03-01", "count" => 5} = st3
      assert %{"start_date" => "1970-02-01", "count" => 0} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "when no transactions, it returns all periods with count = 0",
         %{
           conn: conn,
           store: store
         } do
      {network_start_time, network_end_time} = network_time_interval()
      network_end_time = network_end_time + 100 * @milliseconds_per_day

      store =
        store
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/transactions", limit: 2, interval_by: "month")
               |> json_response(200)

      assert %{"start_date" => "1970-05-01", "count" => 0} = st1
      assert %{"start_date" => "1970-04-01", "count" => 0} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-03-01", "count" => 0} = st3
      assert %{"start_date" => "1970-02-01", "count" => 0} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)

      assert 0 ==
               conn
               |> get("/v3/stats/transactions/total")
               |> json_response(200)
    end
  end

  describe "difficulty_stats" do
    test "it returns the average of block difficulties for the latest daily periods", %{
      conn: conn,
      store: store
    } do
      st1_index = {:difficulty, :day, 29}
      st2_index = {:difficulty, :day, 30}
      st3_index = {:difficulty, :day, 31}
      st1_count_index = {{:blocks, :key}, :day, 29}
      st2_count_index = {{:blocks, :key}, :day, 30}
      st3_count_index = {{:blocks, :key}, :day, 31}
      {network_start_time, network_end_time} = network_time_interval()

      store =
        store
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))
        |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 3))
        |> Store.put(Model.Statistic, Model.statistic(index: st1_count_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_count_index, count: 10))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_count_index, count: 9))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/difficulty", limit: 2)
               |> json_response(200)

      assert %{"start_date" => "1970-02-01", "count" => 0} = st1
      assert %{"start_date" => "1970-01-31", "count" => 1} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-01-30", "count" => 1} = st3
      assert %{"start_date" => "1970-01-29", "count" => 0} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "when interval_by = week, it returns the average of block difficulties for the latest weekly periods",
         %{
           conn: conn,
           store: store
         } do
      st1_index = {:difficulty, :week, 2}
      st2_index = {:difficulty, :week, 3}
      st3_index = {:difficulty, :week, 4}
      st1_count_index = {{:blocks, :key}, :week, 2}
      st2_count_index = {{:blocks, :key}, :week, 3}
      st3_count_index = {{:blocks, :key}, :week, 4}
      {network_start_time, network_end_time} = network_time_interval()

      store =
        store
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))
        |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 3))
        |> Store.put(Model.Statistic, Model.statistic(index: st1_count_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_count_index, count: 10))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_count_index, count: 9))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/difficulty", limit: 2, interval_by: "week")
               |> json_response(200)

      assert %{"start_date" => "1970-01-29", "count" => 0} = st1
      assert %{"start_date" => "1970-01-22", "count" => 1} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-01-15", "count" => 1} = st3
      assert %{"start_date" => "1970-01-08", "count" => 0} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "when no block difficulties, it returns all periods with average = 0",
         %{
           conn: conn,
           store: store
         } do
      {network_start_time, network_end_time} = network_time_interval()
      network_end_time = network_end_time + 100 * @milliseconds_per_day

      store =
        store
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/difficulty", limit: 2, interval_by: "month")
               |> json_response(200)

      assert %{"start_date" => "1970-05-01", "count" => 0} = st1
      assert %{"start_date" => "1970-04-01", "count" => 0} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-03-01", "count" => 0} = st3
      assert %{"start_date" => "1970-02-01", "count" => 0} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "when interval_by = month, it returns the average of block difficulties for the latest monthly periods",
         %{
           conn: conn,
           store: store
         } do
      st1_index = {:difficulty, :month, 0}
      st2_index = {:difficulty, :month, 2}
      st3_index = {:difficulty, :month, 3}
      st4_index = {:difficulty, :month, 4}
      st1_count_index = {{:blocks, :key}, :month, 0}
      st2_count_index = {{:blocks, :key}, :month, 2}
      st3_count_index = {{:blocks, :key}, :month, 3}
      st4_count_index = {{:blocks, :key}, :month, 4}

      {network_start_time, network_end_time} = network_time_interval()
      network_end_time = network_end_time + 100 * @milliseconds_per_day

      store =
        store
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))
        |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 3))
        |> Store.put(Model.Statistic, Model.statistic(index: st4_index, count: 8))
        |> Store.put(Model.Statistic, Model.statistic(index: st1_count_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_count_index, count: 10))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_count_index, count: 9))
        |> Store.put(Model.Statistic, Model.statistic(index: st4_count_index, count: 16))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/difficulty", limit: 2, interval_by: "month")
               |> json_response(200)

      assert %{"start_date" => "1970-05-01", "count" => 1} = st1
      assert %{"start_date" => "1970-04-01", "count" => 0} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-03-01", "count" => 1} = st3
      assert %{"start_date" => "1970-02-01", "count" => 0} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end
  end

  describe "hashrate_stats" do
    test "it returns the average of block hashrates for the latest daily periods", %{
      conn: conn,
      store: store
    } do
      st1_index = {:hashrate, :day, 29}
      st2_index = {:hashrate, :day, 30}
      st3_index = {:hashrate, :day, 31}
      st1_count_index = {{:blocks, :key}, :day, 29}
      st2_count_index = {{:blocks, :key}, :day, 30}
      st3_count_index = {{:blocks, :key}, :day, 31}
      {network_start_time, network_end_time} = network_time_interval()

      store =
        store
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))
        |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 3))
        |> Store.put(Model.Statistic, Model.statistic(index: st1_count_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_count_index, count: 10))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_count_index, count: 9))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/hashrate", limit: 2)
               |> json_response(200)

      assert %{"start_date" => "1970-02-01", "count" => 0} = st1
      assert %{"start_date" => "1970-01-31", "count" => 1} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-01-30", "count" => 1} = st3
      assert %{"start_date" => "1970-01-29", "count" => 0} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "when interval_by = week, it returns the average of block hashrates for the latest weekly periods",
         %{
           conn: conn,
           store: store
         } do
      st1_index = {:hashrate, :week, 2}
      st2_index = {:hashrate, :week, 3}
      st3_index = {:hashrate, :week, 4}
      st1_count_index = {{:blocks, :key}, :week, 2}
      st2_count_index = {{:blocks, :key}, :week, 3}
      st3_count_index = {{:blocks, :key}, :week, 4}
      {network_start_time, network_end_time} = network_time_interval()

      store =
        store
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))
        |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 3))
        |> Store.put(Model.Statistic, Model.statistic(index: st1_count_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_count_index, count: 10))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_count_index, count: 9))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/hashrate", limit: 2, interval_by: "week")
               |> json_response(200)

      assert %{"start_date" => "1970-01-29", "count" => 0} = st1
      assert %{"start_date" => "1970-01-22", "count" => 1} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-01-15", "count" => 1} = st3
      assert %{"start_date" => "1970-01-08", "count" => 0} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "when no block hashrates, it returns all periods with average = 0",
         %{
           conn: conn,
           store: store
         } do
      {network_start_time, network_end_time} = network_time_interval()
      network_end_time = network_end_time + 100 * @milliseconds_per_day

      store =
        store
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/hashrate", limit: 2, interval_by: "month")
               |> json_response(200)

      assert %{"start_date" => "1970-05-01", "count" => 0} = st1
      assert %{"start_date" => "1970-04-01", "count" => 0} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-03-01", "count" => 0} = st3
      assert %{"start_date" => "1970-02-01", "count" => 0} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "when interval_by = month, it returns the average of block hashrates for the latest monthly periods",
         %{
           conn: conn,
           store: store
         } do
      st1_index = {:hashrate, :month, 0}
      st2_index = {:hashrate, :month, 2}
      st3_index = {:hashrate, :month, 3}
      st4_index = {:hashrate, :month, 4}
      st1_count_index = {{:blocks, :key}, :month, 0}
      st2_count_index = {{:blocks, :key}, :month, 2}
      st3_count_index = {{:blocks, :key}, :month, 3}
      st4_count_index = {{:blocks, :key}, :month, 4}

      {network_start_time, network_end_time} = network_time_interval()
      network_end_time = network_end_time + 100 * @milliseconds_per_day

      store =
        store
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))
        |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 3))
        |> Store.put(Model.Statistic, Model.statistic(index: st4_index, count: 8))
        |> Store.put(Model.Statistic, Model.statistic(index: st1_count_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_count_index, count: 10))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_count_index, count: 9))
        |> Store.put(Model.Statistic, Model.statistic(index: st4_count_index, count: 16))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/hashrate", limit: 2, interval_by: "month")
               |> json_response(200)

      assert %{"start_date" => "1970-05-01", "count" => 1} = st1
      assert %{"start_date" => "1970-04-01", "count" => 0} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-03-01", "count" => 1} = st3
      assert %{"start_date" => "1970-02-01", "count" => 0} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end
  end

  describe "blocks_stats" do
    test "it returns the count of blocks for the latest daily periods", %{
      conn: conn,
      store: store
    } do
      st1_index = {{:blocks, :all}, :day, 27}
      st2_index = {{:blocks, :all}, :day, 28}
      st3_index = {{:blocks, :all}, :day, 29}
      st4_index = {{:blocks, :all}, :day, 30}
      {network_start_time, network_end_time} = network_time_interval()

      store =
        store
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))
        |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 3))
        |> Store.put(Model.Statistic, Model.statistic(index: st4_index, count: 2))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/blocks", limit: 2)
               |> json_response(200)

      assert %{"start_date" => "1970-02-01", "count" => 0} = st1
      assert %{"start_date" => "1970-01-31", "count" => 2} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-01-30", "count" => 3} = st3
      assert %{"start_date" => "1970-01-29", "count" => 5} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "when scoping, it returns the count of blocks for the given blocks period", %{
      conn: conn,
      store: store
    } do
      st1_index = {{:blocks, :all}, :day, 0}
      st2_index = {{:blocks, :all}, :day, 1}
      st3_index = {{:blocks, :all}, :day, 2}
      st4_index = {{:blocks, :all}, :day, 3}
      {network_start_time, network_end_time} = network_time_interval()
      day = 3_600 * 24 * 1_000
      time1 = network_start_time
      time2 = network_start_time + 4 * day

      store =
        store
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))
        |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 3))
        |> Store.put(Model.Statistic, Model.statistic(index: st4_index, count: 2))
        |> Store.put(Model.Block, Model.block(index: {1, -1}, tx_index: 0))
        |> Store.put(Model.Block, Model.block(index: {2, -1}, tx_index: 10))
        |> Store.put(Model.Tx, Model.tx(index: 0, time: time1))
        |> Store.put(Model.Tx, Model.tx(index: 10, time: time2))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/blocks", limit: 2, scope: "gen:1-2")
               |> json_response(200)

      assert %{"start_date" => "1970-01-01", "count" => 1} = st1
      assert %{"start_date" => "1970-01-02", "count" => 5} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-01-03", "count" => 3} = st3
      assert %{"start_date" => "1970-01-04", "count" => 2} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "it returns the count of blocks filtered by a block type", %{conn: conn, store: store} do
      st1_index = {{:blocks, :all}, :day, 0}
      st2_index = {{:blocks, :key}, :day, 1}
      st3_index = {{:blocks, :micro}, :day, 0}
      st4_index = {{:blocks, :micro}, :day, 1}
      st5_index = {{:blocks, :micro}, :day, 3}
      {network_start_time, network_end_time} = network_time_interval()

      store =
        store
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))
        |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st4_index, count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: st5_index, count: 3))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/blocks",
                 limit: 2,
                 type: "micro",
                 direction: "forward"
               )
               |> json_response(200)

      assert %{"start_date" => "1970-01-01", "count" => 1} = st1
      assert %{"start_date" => "1970-01-02", "count" => 5} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-01-03", "count" => 0} = st3
      assert %{"start_date" => "1970-01-04", "count" => 3} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "it returns the count of blocks filtered by a min/max date", %{conn: conn, store: store} do
      st1_index = {{:blocks, :all}, :day, 0}
      st2_index = {{:blocks, :all}, :day, 1}
      st3_index = {{:blocks, :all}, :day, 2}
      st4_index = {{:blocks, :all}, :day, 3}

      store =
        store
        |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 2))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 3))
        |> Store.put(Model.Statistic, Model.statistic(index: st4_index, count: 4))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2], "next" => nil} =
               conn
               |> get("/v3/stats/blocks",
                 limit: 2,
                 min_start_date: "1970-01-02",
                 max_start_date: "1970-01-03",
                 direction: "forward"
               )
               |> json_response(200)

      assert %{"start_date" => "1970-01-02", "count" => 2} = st1
      assert %{"start_date" => "1970-01-03", "count" => 3} = st2
    end

    test "when interval_by = week, it returns the count of blocks for the latest weekly periods",
         %{
           conn: conn,
           store: store
         } do
      st1_index = {{:blocks, :all}, :week, 0}
      st2_index = {{:blocks, :all}, :week, 1}
      st3_index = {{:blocks, :all}, :week, 2}
      {network_start_time, network_end_time} = network_time_interval()

      store =
        store
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))
        |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 3))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/blocks", limit: 2, interval_by: "week")
               |> json_response(200)

      assert %{"start_date" => "1970-01-29", "count" => 0} = st1
      assert %{"start_date" => "1970-01-22", "count" => 0} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-01-15", "count" => 3} = st3
      assert %{"start_date" => "1970-01-08", "count" => 5} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "when block type is invalid, it returns an error", %{conn: conn} do
      block_type = "foo"
      error_msg = "invalid query: type=#{block_type}"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/v3/stats/blocks", type: block_type)
               |> json_response(400)
    end

    test "when limit is less than 1000, it doesn't return an error", %{conn: conn} do
      assert %{"data" => _data} =
               conn
               |> get("/v3/stats/blocks", limit: 1000)
               |> json_response(200)

      assert %{"data" => _data} =
               conn
               |> get("/v3/stats/blocks", limit: 301)
               |> json_response(200)

      assert %{"error" => "invalid query: limit too large `1001`"} =
               conn
               |> get("/v3/stats/blocks", limit: 1001)
               |> json_response(400)
    end
  end

  describe "stats" do
    test "it counts last 24hs transactions and 48hs comparison trend and gets average of fees with trend",
         %{conn: conn, store: store} do
      now = :aeu_time.now_in_msecs()
      three_minutes = 3 * 60 * 1_000

      last_txi = 21

      fee_avg = Enum.sum((last_txi - 3)..last_txi) / Enum.count((last_txi - 3)..last_txi)

      last_48_fee_avg =
        Enum.sum((last_txi - 7)..(last_txi - 4)) / Enum.count((last_txi - 7)..(last_txi - 4))

      txs_count = 4

      encoded_txs_stats =
        {{txs_count, 5}, {fee_avg, last_48_fee_avg}}

      store =
        store
        |> add_transactions_every_5_hours(1, last_txi, now)
        |> Store.put(Model.Stat, Model.stat(index: :miners_count, payload: 2))
        |> Store.put(Model.Stat, Model.stat(index: :max_tps, payload: {2, <<0::256>>}))
        |> Store.put(Model.Stat, Model.stat(index: Stats.holders_count_key(), payload: 3))
        |> Store.put(Model.Stat, Model.stat(index: :tx_stats, payload: {now, encoded_txs_stats}))
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: <<1::256>>))
        |> Store.put(Model.Block, Model.block(index: {10, -1}, hash: <<2::256>>))

      with_mocks([
        {:aec_chain, [],
         get_key_block_by_height: fn
           1 -> {:ok, :first_block}
           _n -> {:ok, :other_block}
         end},
        {:aec_blocks, [],
         time_in_msecs: fn
           :first_block -> now - 10 * three_minutes
           :other_block -> now
         end}
      ]) do
        assert %{
                 "last_24hs_transactions" => 4,
                 "transactions_trend" => -0.25,
                 "fees_trend" => 0.21,
                 "last_24hs_average_transaction_fees" => ^fee_avg,
                 "milliseconds_per_block" => ^three_minutes,
                 "holders_count" => 3
               } =
                 conn
                 |> with_store(store)
                 |> get("/v3/stats")
                 |> json_response(200)
      end
    end

    test "it returns correct data for one transaction", %{
      conn: conn,
      store: store
    } do
      now = :aeu_time.now_in_msecs()
      three_minutes = 3 * 60 * 1_000

      txs_stats =
        {{1, 0}, {1.0, 0}}

      store =
        store
        |> add_transactions_every_5_hours(1, 1, now)
        |> Store.put(Model.Stat, Model.stat(index: :miners_count, payload: 2))
        |> Store.put(Model.Stat, Model.stat(index: :max_tps, payload: {2, <<0::256>>}))
        |> Store.put(Model.Stat, Model.stat(index: Stats.holders_count_key(), payload: 3))
        |> Store.put(Model.Stat, Model.stat(index: :tx_stats, payload: {now, txs_stats}))
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: <<1::256>>))
        |> Store.put(Model.Block, Model.block(index: {10, -1}, hash: <<2::256>>))

      with_mocks([
        {:aec_chain, [],
         get_key_block_by_height: fn
           1 -> {:ok, :first_block}
           _n -> {:ok, :other_block}
         end},
        {:aec_blocks, [],
         time_in_msecs: fn
           :first_block -> now - 10 * three_minutes
           :other_block -> now
         end},
        {RocksDbCF, [],
         stream: fn
           Model.Tx, [key_boundary: {start_txi, end_txi}] ->
             store
             |> State.new()
             |> Collection.stream(Model.Tx, :forward, {start_txi, end_txi}, nil)
             |> Stream.map(fn index ->
               {:ok, tx} = Store.get(store, Model.Tx, index)
               tx
             end)
         end}
      ]) do
        assert %{
                 "last_24hs_transactions" => 1,
                 "transactions_trend" => 1.0,
                 "fees_trend" => 1.0,
                 "last_24hs_average_transaction_fees" => 1.0,
                 "milliseconds_per_block" => ^three_minutes,
                 "holders_count" => 3
               } =
                 conn
                 |> with_store(store)
                 |> get("/v3/stats")
                 |> json_response(200)
      end
    end

    test "it doesn't return error when there is no new transaction last 24h", %{
      conn: conn,
      store: store
    } do
      now = :aeu_time.now_in_msecs()
      three_minutes = 3 * 60 * 1_000

      store =
        store
        |> Store.put(Model.Stat, Model.stat(index: :miners_count, payload: 2))
        |> Store.put(Model.Stat, Model.stat(index: :max_tps, payload: {2, <<0::256>>}))
        |> Store.put(Model.Stat, Model.stat(index: Stats.holders_count_key(), payload: 3))
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: <<1::256>>))
        |> Store.put(Model.Block, Model.block(index: {10, -1}, hash: <<2::256>>))

      with_mocks([
        {:aec_chain, [],
         get_key_block_by_height: fn
           1 -> {:ok, :first_block}
           _n -> {:ok, :other_block}
         end},
        {:aec_blocks, [],
         time_in_msecs: fn
           :first_block -> now - 10 * three_minutes
           :other_block -> now
         end}
      ]) do
        assert %{
                 "last_24hs_transactions" => 0,
                 "transactions_trend" => 0,
                 "fees_trend" => 0,
                 "last_24hs_average_transaction_fees" => 0,
                 "milliseconds_per_block" => ^three_minutes,
                 "holders_count" => 3
               } =
                 conn
                 |> with_store(store)
                 |> get("/v3/stats")
                 |> json_response(200)
      end
    end
  end

  describe "top miners stats" do
    setup %{store: store, conn: conn} do
      miner1 = <<1::256>>
      miner2 = <<2::256>>
      miner3 = <<3::256>>
      miner4 = <<4::256>>
      {network_start_time, network_end_time} = network_time_interval()

      store =
        [
          Model.top_miner_stats(index: {:day, 0, 7, miner1}),
          Model.top_miner_stats(index: {:day, 0, 6, miner2}),
          Model.top_miner_stats(index: {:day, 0, 5, miner3}),
          Model.top_miner_stats(index: {:day, 0, 4, miner4}),
          Model.top_miner_stats(index: {:day, 1, 1, miner1}),
          Model.top_miner_stats(index: {:day, 1, 2, miner2}),
          Model.top_miner_stats(index: {:day, 1, 3, miner3}),
          Model.top_miner_stats(index: {:day, 1, 4, miner4}),
          Model.top_miner_stats(index: {:week, 0, 8, miner1}),
          Model.top_miner_stats(index: {:week, 0, 8, miner2}),
          Model.top_miner_stats(index: {:week, 0, 8, miner3}),
          Model.top_miner_stats(index: {:week, 0, 8, miner4}),
          Model.top_miner_stats(index: {:week, 1, 8, miner1}),
          Model.top_miner_stats(index: {:week, 1, 8, miner2}),
          Model.top_miner_stats(index: {:week, 1, 8, miner3}),
          Model.top_miner_stats(index: {:week, 1, 8, miner4}),
          Model.top_miner_stats(index: {:month, 0, 16, miner1}),
          Model.top_miner_stats(index: {:month, 0, 16, miner2}),
          Model.top_miner_stats(index: {:month, 0, 16, miner3}),
          Model.top_miner_stats(index: {:month, 0, 16, miner4})
        ]
        |> Enum.reduce(store, fn mutation, store ->
          Store.put(store, Model.TopMinerStats, mutation)
        end)
        |> Store.put(Model.Time, Model.time(index: {network_start_time, 0}))
        |> Store.put(Model.Time, Model.time(index: {network_end_time, 200}))

      miners =
        [
          miner1,
          miner2,
          miner3,
          miner4
        ]
        |> Enum.map(&:aeapi.format_account_pubkey/1)

      conn = with_store(conn, store)

      {:ok, %{store: store, miners: miners, conn: conn}}
    end

    test "it returns the top miners for specific date", %{conn: conn, miners: miners} do
      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/miners/top",
                 limit: 2,
                 min_start_date: "1970-01-01",
                 max_start_date: "1970-01-01"
               )
               |> json_response(200)

      [miner1, miner2, miner3, miner4] = miners
      assert %{"miner" => ^miner1, "blocks_mined" => 7} = st1
      assert %{"miner" => ^miner2, "blocks_mined" => 6} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4], "next" => nil} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"miner" => ^miner3, "blocks_mined" => 5} = st3
      assert %{"miner" => ^miner4, "blocks_mined" => 4} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "it returns the top miners for each day", %{conn: conn, miners: miners} do
      assert %{"prev" => nil, "data" => [st1, st2, st3, st4] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/miners/top",
                 limit: 4,
                 min_start_date: "1970-01-01",
                 max_start_date: "1970-01-02"
               )
               |> json_response(200)

      [miner1, miner2, miner3, miner4] = miners

      assert %{"miner" => ^miner4, "blocks_mined" => 4} = st1
      assert %{"miner" => ^miner3, "blocks_mined" => 3} = st2
      assert %{"miner" => ^miner2, "blocks_mined" => 2} = st3
      assert %{"miner" => ^miner1, "blocks_mined" => 1} = st4

      assert %{"prev" => prev_url, "data" => [st5, st6, st7, st8], "next" => nil} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"miner" => ^miner1, "blocks_mined" => 7} = st5
      assert %{"miner" => ^miner2, "blocks_mined" => 6} = st6
      assert %{"miner" => ^miner3, "blocks_mined" => 5} = st7
      assert %{"miner" => ^miner4, "blocks_mined" => 4} = st8

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "it returns top miners for a week", %{conn: conn, miners: miners} do
      [miner1, miner2, miner3, miner4] = miners

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/miners/top",
                 limit: 2,
                 interval_by: "week",
                 min_start_date: "1970-01-01",
                 max_start_date: "1970-01-07"
               )
               |> json_response(200)

      assert %{"miner" => ^miner4, "blocks_mined" => 8} = st1
      assert %{"miner" => ^miner3, "blocks_mined" => 8} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4], "next" => nil} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"miner" => ^miner2, "blocks_mined" => 8} = st3
      assert %{"miner" => ^miner1, "blocks_mined" => 8} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "it returns top miners for multiple weeks", %{conn: conn, miners: miners} do
      [miner1, miner2, miner3, miner4] = miners

      assert %{"prev" => nil, "data" => [st1, st2, st3, st4] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/miners/top",
                 limit: 4,
                 interval_by: "week",
                 min_start_date: "1970-01-01",
                 max_start_date: "1970-01-13"
               )
               |> json_response(200)

      assert %{"miner" => ^miner4, "blocks_mined" => 8, "start_date" => "1970-01-08"} = st1
      assert %{"miner" => ^miner3, "blocks_mined" => 8, "start_date" => "1970-01-08"} = st2
      assert %{"miner" => ^miner2, "blocks_mined" => 8, "start_date" => "1970-01-08"} = st3
      assert %{"miner" => ^miner1, "blocks_mined" => 8, "start_date" => "1970-01-08"} = st4

      assert %{"prev" => prev_url, "data" => [st5, st6, st7, st8], "next" => nil} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"miner" => ^miner4, "blocks_mined" => 8, "start_date" => "1970-01-01"} = st5
      assert %{"miner" => ^miner3, "blocks_mined" => 8, "start_date" => "1970-01-01"} = st6
      assert %{"miner" => ^miner2, "blocks_mined" => 8, "start_date" => "1970-01-01"} = st7
      assert %{"miner" => ^miner1, "blocks_mined" => 8, "start_date" => "1970-01-01"} = st8

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "it returns top miners for a month", %{conn: conn, miners: miners} do
      [miner1, miner2, miner3, miner4] = miners

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/stats/miners/top",
                 limit: 2,
                 interval_by: "month",
                 min_start_date: "1970-01-01",
                 max_start_date: "1970-01-31"
               )
               |> json_response(200)

      assert %{"miner" => ^miner4, "blocks_mined" => 16} = st1
      assert %{"miner" => ^miner3, "blocks_mined" => 16} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4], "next" => nil} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"miner" => ^miner2, "blocks_mined" => 16} = st3
      assert %{"miner" => ^miner1, "blocks_mined" => 16} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end
  end

  describe "top miners for the last 24hs" do
    setup %{conn: conn, store: store} do
      now = :aeu_time.now_in_msecs()
      second = 1_000
      minute = 60 * second
      hour = 60 * minute
      day = 24 * hour
      miner_ids = [<<1::256>>, <<2::256>>, <<3::256>>]
      miner_pks = Enum.map(miner_ids, &:aeapi.format_account_pubkey/1)

      miners = [
        {now - second, Enum.at(miner_ids, 0)},
        {now - minute, Enum.at(miner_ids, 1)},
        {now - 30 * minute, Enum.at(miner_ids, 2)},
        {now - hour, Enum.at(miner_ids, 0)},
        {now - 2 * hour, Enum.at(miner_ids, 1)},
        {now - 12 * hour, Enum.at(miner_ids, 2)},
        {now - day, Enum.at(miner_ids, 0)},
        {now - day + minute, Enum.at(miner_ids, 1)},
        {now - day - minute, Enum.at(miner_ids, 2)},
        {now - 2 * day + minute, Enum.at(miner_ids, 0)},
        {now - 2 * day + hour, Enum.at(miner_ids, 1)},
        {now - 2 * day + second, Enum.at(miner_ids, 2)},
        {now - 3 * day, Enum.at(miner_ids, 1)}
      ]

      store =
        Enum.reduce(miners, store, fn {time, miner}, store ->
          store
          |> Store.put(
            Model.KeyBlockTime,
            Model.key_block_time(index: time, miner: miner)
          )
        end)

      conn = with_store(conn, store)

      {:ok, %{store: store, conn: conn, now: now, miner_pks: miner_pks, day: day}}
    end

    test "it returns top miners for the last 24hs", %{conn: conn, now: now, miner_pks: miner_pks} do
      with_mocks([{:aeu_time, [], now_in_msecs: fn -> now end}]) do
        assert [st1, st2, st3] =
                 conn
                 |> get("/v3/stats/miners/top-24h")
                 |> json_response(200)

        [miner1, miner2, miner3] = miner_pks
        assert %{"miner" => ^miner1, "blocks_mined" => 3} = st1
        assert %{"miner" => ^miner2, "blocks_mined" => 3} = st2
        assert %{"miner" => ^miner3, "blocks_mined" => 2} = st3
      end
    end

    test "it returns top miners for the last 24hs when no mined blocks (mdw out of sync)", %{
      conn: conn,
      now: now,
      day: day
    } do
      with_mocks([{:aeu_time, [], now_in_msecs: fn -> now + day end}]) do
        assert [] =
                 conn
                 |> get("/v3/stats/miners/top-24h")
                 |> json_response(200)
      end
    end

    test "it returns top miners for the last 24hs, but there are blocks in the future", %{
      conn: conn,
      now: now,
      miner_pks: miner_pks,
      day: day
    } do
      with_mocks([{:aeu_time, [], now_in_msecs: fn -> now - day end}]) do
        assert [st1, st2, st3] =
                 conn
                 |> get("/v3/stats/miners/top-24h")
                 |> json_response(200)

        [miner1, miner2, miner3] = miner_pks

        assert %{"miner" => ^miner1, "blocks_mined" => 2} = st1
        assert %{"miner" => ^miner2, "blocks_mined" => 1} = st2
        assert %{"miner" => ^miner3, "blocks_mined" => 2} = st3
      end
    end
  end

  defp add_transactions_every_5_hours(store, start_txi, end_txi, now) do
    end_txi..start_txi
    |> Enum.reduce({store, 1}, fn txi, {store, i} ->
      {
        store
        |> Store.put(Model.Tx, Model.tx(index: txi, id: <<txi::256>>, fee: txi))
        |> Store.put(
          Model.Time,
          Model.time(index: {now - :timer.hours(i * 5), txi})
        ),
        i + 1
      }
    end)
    |> elem(0)
  end

  defp network_time_interval do
    start_time = DateTime.new!(Date.new!(1970, 1, 1), Time.new!(0, 0, 0))
    end_time = DateTime.new!(Date.new!(1970, 2, 1), Time.new!(0, 0, 0))

    {
      DateTime.to_unix(start_time, :millisecond),
      DateTime.to_unix(end_time, :millisecond)
    }
  end
end

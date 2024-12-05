defmodule AeMdwWeb.StatsControllerTest do
  use AeMdwWeb.ConnCase, async: false
  import Mock

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store

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
      st1_index = {{:transactions, :all}, :day, 29}
      st2_index = {{:transactions, :all}, :day, 30}
      st3_index = {{:transactions, :all}, :day, 31}
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
    end

    test "it returns the count of transactions filtered by a tx type", %{conn: conn, store: store} do
      st1_index = {{:transactions, :all}, :day, 0}
      st2_index = {{:transactions, :oracle_register_tx}, :day, 0}
      st3_index = {{:transactions, :spend_tx}, :day, 0}
      st4_index = {{:transactions, :spend_tx}, :day, 1}
      st5_index = {{:transactions, :spend_tx}, :day, 3}
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
    end

    test "when interval_by = week, it returns the count of transactions for the latest weekly periods",
         %{
           conn: conn,
           store: store
         } do
      st1_index = {{:transactions, :all}, :week, 2}
      st2_index = {{:transactions, :all}, :week, 3}
      st3_index = {{:transactions, :all}, :week, 4}
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

      assert %{"error" => "limit too large: 1001"} =
               conn
               |> get("/v3/stats/blocks", limit: 1001)
               |> json_response(400)
    end
  end

  describe "stats" do
    test "it counts last 24hs transactions and 48hs comparison trend and gets average of fees with trend",
         %{conn: conn, store: store} do
      now = :aeu_time.now_in_msecs()
      msecs_per_day = 3_600 * 24 * 1_000
      three_minutes = 3 * 60 * 1_000
      delay = 500

      last_24hs_start_txi = 8
      last_txi = 21

      store =
        store
        |> add_transactions(1, last_txi)
        |> Store.put(
          Model.Time,
          Model.time(index: {now - msecs_per_day + delay, last_24hs_start_txi})
        )
        |> Store.put(Model.Time, Model.time(index: {now - msecs_per_day * 2 + delay, 1}))
        |> Store.put(Model.Stat, Model.stat(index: :miners_count, payload: 2))
        |> Store.put(Model.Stat, Model.stat(index: :max_tps, payload: {2, <<0::256>>}))
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: <<1::256>>))
        |> Store.put(Model.Block, Model.block(index: {10, -1}, hash: <<2::256>>))

      txis = last_24hs_start_txi..last_txi

      fee_avg = Enum.sum(txis) / Enum.count(txis)

      with_mocks([
        {AeMdw.Node.Db, [], get_tx_fee: fn <<i::256>> -> i end},
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
                 "last_24hs_transactions" => 13,
                 "transactions_trend" => 0.46,
                 "fees_trend" => 0.69,
                 "last_24hs_average_transaction_fees" => ^fee_avg,
                 "milliseconds_per_block" => ^three_minutes
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
      msecs_per_day = 3_600 * 24 * 1_000
      three_minutes = 3 * 60 * 1_000
      delay = 500

      last_txi = 21

      store =
        store
        |> add_transactions(1, last_txi)
        |> Store.put(
          Model.Time,
          Model.time(index: {now - msecs_per_day + delay, last_txi})
        )
        |> Store.put(Model.Time, Model.time(index: {now - msecs_per_day * 2 + delay, 1}))
        |> Store.put(Model.Stat, Model.stat(index: :miners_count, payload: 2))
        |> Store.put(Model.Stat, Model.stat(index: :max_tps, payload: {2, <<0::256>>}))
        |> Store.put(Model.Block, Model.block(index: {1, -1}, hash: <<1::256>>))
        |> Store.put(Model.Block, Model.block(index: {10, -1}, hash: <<2::256>>))

      with_mocks([
        {AeMdw.Node.Db, [], get_tx_fee: fn <<i::256>> -> i end},
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
                 "milliseconds_per_block" => ^three_minutes
               } =
                 conn
                 |> with_store(store)
                 |> get("/v3/stats")
                 |> json_response(200)
      end
    end
  end

  defp add_transactions(store, start_txi, end_txi) do
    start_txi..end_txi
    |> Enum.reduce({store, 1}, fn txi, {store, i} ->
      {Store.put(store, Model.Tx, Model.tx(index: txi, id: <<i::256>>)), i + 1}
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

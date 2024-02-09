defmodule AeMdwWeb.StatsControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Model
  alias AeMdw.Db.Store

  require Model

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
      st1_index = {{:transactions, :all}, :day, 1_000}
      st2_index = {{:transactions, :all}, :day, 2_000}
      st3_index = {{:transactions, :all}, :day, 3_000}

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

      assert %{"start_date" => "1978-03-20", "count" => 3} = st1
      assert %{"start_date" => "1975-06-24", "count" => 5} = st2

      assert %{"prev" => prev_url, "data" => [st3]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1972-09-27", "count" => 1} = st3

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "it returns the count of transactions filtered by a tx type", %{conn: conn, store: store} do
      st1_index = {{:transactions, :all}, :day, 500}
      st2_index = {{:transactions, :oracle_register_tx}, :day, 500}
      st3_index = {{:transactions, :spend_tx}, :day, 1_000}
      st4_index = {{:transactions, :spend_tx}, :day, 2_000}
      st5_index = {{:transactions, :spend_tx}, :day, 3_000}

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

      assert %{"start_date" => "1972-09-27", "count" => 1} = st1
      assert %{"start_date" => "1975-06-24", "count" => 5} = st2

      assert %{"prev" => prev_url, "data" => [st3]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1978-03-20", "count" => 3} = st3

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
      st1_index = {{:transactions, :all}, :week, 0}
      st2_index = {{:transactions, :all}, :week, 1_000}
      st3_index = {{:transactions, :all}, :week, 2_000}

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

      assert %{"start_date" => "2008-05-01", "count" => 3} = st1
      assert %{"start_date" => "1989-03-02", "count" => 5} = st2

      assert %{"prev" => prev_url, "data" => [st3]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-01-01", "count" => 1} = st3

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
      st2_index = {{:transactions, :all}, :month, 12}
      st3_index = {{:transactions, :all}, :month, 24}
      st4_index = {{:transactions, :all}, :month, 36}

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

      assert %{"start_date" => "1973-01-01", "count" => 8} = st1
      assert %{"start_date" => "1972-01-01", "count" => 3} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1971-01-01", "count" => 5} = st3
      assert %{"start_date" => "1970-01-01", "count" => 1} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end
  end

  describe "blocks_statistics" do
    test "it returns the count of blocks for the latest daily periods", %{
      conn: conn,
      store: store
    } do
      st1_index = {{:blocks, :all}, :day, 1}
      st2_index = {{:blocks, :all}, :day, 365}
      st3_index = {{:blocks, :all}, :day, 366}
      st4_index = {{:blocks, :all}, :day, 730}

      store =
        store
        |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 3))
        |> Store.put(Model.Statistic, Model.statistic(index: st4_index, count: 2))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/statistics/blocks", limit: 2)
               |> json_response(200)

      assert %{"start_date" => "1972-01-01", "count" => 2} = st1
      assert %{"start_date" => "1971-01-02", "count" => 3} = st2

      assert %{"prev" => prev_url, "data" => [st3, st4]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1971-01-01", "count" => 5} = st3
      assert %{"start_date" => "1970-01-02", "count" => 1} = st4

      assert %{"data" => ^statistics} =
               conn
               |> get(prev_url)
               |> json_response(200)
    end

    test "it returns the count of blocks filtered by a block type", %{conn: conn, store: store} do
      st1_index = {{:blocks, :all}, :day, 500}
      st2_index = {{:blocks, :key}, :day, 500}
      st3_index = {{:blocks, :micro}, :day, 1}
      st4_index = {{:blocks, :micro}, :day, 2}
      st5_index = {{:blocks, :micro}, :day, 366}

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
               |> get("/v3/statistics/blocks",
                 limit: 2,
                 type: "micro",
                 direction: "forward"
               )
               |> json_response(200)

      assert %{"start_date" => "1970-01-02", "count" => 1} = st1
      assert %{"start_date" => "1970-01-03", "count" => 5} = st2

      assert %{"prev" => prev_url, "data" => [st3]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1971-01-02", "count" => 3} = st3

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
               |> get("/v3/statistics/blocks",
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
      st2_index = {{:blocks, :all}, :week, 1_000}
      st3_index = {{:blocks, :all}, :week, 2_000}

      store =
        store
        |> Store.put(Model.Statistic, Model.statistic(index: st1_index, count: 1))
        |> Store.put(Model.Statistic, Model.statistic(index: st2_index, count: 5))
        |> Store.put(Model.Statistic, Model.statistic(index: st3_index, count: 3))

      conn = with_store(conn, store)

      assert %{"prev" => nil, "data" => [st1, st2] = statistics, "next" => next_url} =
               conn
               |> get("/v3/statistics/blocks", limit: 2, interval_by: "week")
               |> json_response(200)

      assert %{"start_date" => "2008-05-01", "count" => 3} = st1
      assert %{"start_date" => "1989-03-02", "count" => 5} = st2

      assert %{"prev" => prev_url, "data" => [st3]} =
               conn
               |> get(next_url)
               |> json_response(200)

      assert %{"start_date" => "1970-01-01", "count" => 1} = st3

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
               |> get("/v3/statistics/blocks", type: block_type)
               |> json_response(400)
    end

    test "when limit is less than 1000, it doesn't return an error", %{conn: conn} do
      assert %{"data" => _data} =
               conn
               |> get("/v3/statistics/blocks", limit: 1000)
               |> json_response(200)

      assert %{"data" => _data} =
               conn
               |> get("/v3/statistics/blocks", limit: 301)
               |> json_response(200)

      assert %{"error" => "limit too large: 1001"} =
               conn
               |> get("/v3/statistics/blocks", limit: 1001)
               |> json_response(400)
    end
  end

  describe "stats" do
    test "it counts last 24hs transactions and 48hs comparison trend", %{conn: conn, store: store} do
      now = :aeu_time.now_in_msecs()
      msecs_per_day = 3_600 * 24 * 1_000
      delay = 10

      store =
        store
        |> Store.put(Model.Tx, Model.tx(index: 21))
        |> Store.put(Model.Time, Model.time(index: {now - msecs_per_day + delay, 7}))
        |> Store.put(Model.Time, Model.time(index: {now - msecs_per_day * 2 + delay, 0}))
        |> Store.put(Model.Stat, Model.stat(index: :miners_count, payload: 2))
        |> Store.put(Model.Stat, Model.stat(index: :max_tps, payload: {2, <<0::256>>}))

      assert %{"last_24hs_transactions" => 14, "transactions_trend" => 0.5} =
               conn
               |> with_store(store)
               |> get("/v2/stats")
               |> json_response(200)
    end
  end
end

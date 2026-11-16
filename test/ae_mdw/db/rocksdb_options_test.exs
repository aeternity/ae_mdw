defmodule AeMdw.Db.RocksDbOptionsTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDb

  @unset [
    max_open_files: nil,
    block_cache_mb: nil,
    max_background_jobs: nil,
    max_total_wal_size_mb: nil,
    bloom_filter_tables: []
  ]
  @out_of_range [
    max_open_files: 0,
    max_open_files: -2,
    block_cache_mb: 0,
    max_background_jobs: 0,
    max_total_wal_size_mb: 0
  ]
  @env_vars ~w(MDW_DB_MAX_OPEN_FILES MDW_DB_BLOCK_CACHE_MB MDW_DB_MAX_BACKGROUND_JOBS
               MDW_DB_MAX_TOTAL_WAL_SIZE_MB MDW_DB_BLOOM_FILTER_TABLES)

  describe "open/1" do
    @describetag :tmp_dir

    setup %{tmp_dir: tmp_dir} do
      config = Application.fetch_env!(:ae_mdw, RocksDb)
      :ok = RocksDb.close()

      on_exit(fn ->
        Application.put_env(:ae_mdw, RocksDb, config)
        :ok = RocksDb.open(false)
      end)

      %{config: config |> Keyword.merge(@unset) |> Keyword.put(:data_dir, tmp_dir)}
    end

    test "keeps the options of previous releases by default", %{config: config} do
      with_db(config, [], fn ->
        assert %{
                 "max_open_files" => "500",
                 "max_background_jobs" => "2",
                 "max_total_wal_size" => "0"
               } = options(config, "DBOptions")

        for table <- [Model.Tx, Model.IdCount] do
          assert %{
                   "compression" => "kLZ4Compression",
                   "bottommost_compression" => "kZSTD",
                   "write_buffer_size" => "67108864"
                 } = options(config, ~s(CFOptions "#{table}"))

          assert %{
                   "block_size" => "4096",
                   "format_version" => "5",
                   "cache_index_and_filter_blocks" => "false",
                   "filter_policy" => "nullptr"
                 } = options(config, ~s(TableOptions/BlockBasedTable "#{table}"))
        end
      end)
    end

    test "gives each table its own 8 MB block cache by default", %{config: config} do
      with_db(config, [], fn ->
        read_from_disk(Model.Tx)

        assert cache_property(Model.Tx, "capacity") == 8 * 1024 * 1024
        assert cache_property(Model.IdCount, "capacity") == 8 * 1024 * 1024
        assert cache_property(Model.IdCount, "usage") < cache_property(Model.Tx, "usage")
      end)
    end

    test "shares one block cache of the configured size between all tables", %{config: config} do
      with_db(config, [block_cache_mb: 16], fn ->
        read_from_disk(Model.Tx)

        assert cache_property(Model.Tx, "capacity") == 16 * 1024 * 1024
        assert cache_property(Model.IdCount, "capacity") == 16 * 1024 * 1024
        assert cache_property(Model.Tx, "usage") > 0
        assert cache_property(Model.IdCount, "usage") == cache_property(Model.Tx, "usage")
      end)
    end

    test "applies the configured open files limit, background jobs and WAL size",
         %{config: config} do
      overrides = [max_open_files: 64, max_background_jobs: 4, max_total_wal_size_mb: 2]

      with_db(config, overrides, fn ->
        assert %{
                 "max_open_files" => "64",
                 "max_background_jobs" => "4",
                 "max_total_wal_size" => "2097152"
               } = options(config, "DBOptions")
      end)

      with_db(config, [max_open_files: -1], fn ->
        assert %{"max_open_files" => "-1"} = options(config, "DBOptions")
      end)
    end

    test "writes bloom filters only for the configured tables", %{config: config} do
      with_db(config, [bloom_filter_tables: ["IdCount"]], fn ->
        for table <- [Model.IdCount, Model.Tx] do
          :ok = RocksDb.dirty_put(table, "key", "value")
          flush(table)
        end

        assert filter_size(Model.IdCount) > 0
        assert filter_size(Model.Tx) == 0
        assert {:ok, "value"} = RocksDb.get(Model.IdCount, "key")
        assert :not_found = RocksDb.get(Model.IdCount, "missing")
      end)
    end

    test "keeps the data readable when bloom filters are turned on and off", %{config: config} do
      with_db(config, [], fn ->
        :ok = RocksDb.dirty_put(Model.IdCount, "old", "1")
        flush(Model.IdCount)
      end)

      with_db(config, [bloom_filter_tables: ["IdCount"]], fn ->
        assert {:ok, "1"} = RocksDb.get(Model.IdCount, "old")
        assert filter_size(Model.IdCount) == 0

        :ok = RocksDb.dirty_put(Model.IdCount, "new", "2")
        flush(Model.IdCount)

        assert filter_size(Model.IdCount) > 0
      end)

      with_db(config, [], fn ->
        assert {:ok, "1"} = RocksDb.get(Model.IdCount, "old")
        assert {:ok, "2"} = RocksDb.get(Model.IdCount, "new")
      end)
    end

    test "fails on an unknown bloom filter table", %{config: config} do
      put_config(config, bloom_filter_tables: ["IdCount", "NoSuchTable"])

      assert_raise ArgumentError, ~r/"NoSuchTable"/, fn -> RocksDb.open(false) end
    end

    test "fails on out of range values", %{config: config} do
      for invalid <- @out_of_range do
        put_config(config, [invalid])

        assert_raise FunctionClauseError, fn -> RocksDb.open(false) end
      end
    end
  end

  describe "config/runtime.exs" do
    test "leaves the options unset without the variables" do
      assert runtime_config(%{}) == Map.new(@unset)
    end

    test "reads the variables" do
      assert runtime_config(%{
               "MDW_DB_MAX_OPEN_FILES" => "-1",
               "MDW_DB_BLOCK_CACHE_MB" => "1024",
               "MDW_DB_MAX_BACKGROUND_JOBS" => "4",
               "MDW_DB_MAX_TOTAL_WAL_SIZE_MB" => "2048",
               "MDW_DB_BLOOM_FILTER_TABLES" => " IdCount, ,DupIdCount,"
             }) == %{
               max_open_files: -1,
               block_cache_mb: 1024,
               max_background_jobs: 4,
               max_total_wal_size_mb: 2048,
               bloom_filter_tables: ["IdCount", "DupIdCount"]
             }
    end

    test "fails on a value that is not an integer" do
      assert_raise ArgumentError, fn -> runtime_config(%{"MDW_DB_BLOCK_CACHE_MB" => "1GB"}) end
    end
  end

  defp with_db(config, overrides, fun) do
    put_config(config, overrides)
    :ok = RocksDb.open(false)

    try do
      fun.()
    after
      :ok = RocksDb.close()
    end
  end

  defp put_config(config, overrides),
    do: Application.put_env(:ae_mdw, RocksDb, Keyword.merge(config, overrides))

  # writes a key to an SST file and reads it back, loading its block into the block cache
  defp read_from_disk(table) do
    :ok = RocksDb.dirty_put(table, "key", "value")
    flush(table)

    assert {:ok, "value"} = RocksDb.get(table, "key")
  end

  defp flush(table) do
    {db_ref, cf_ref} = :persistent_term.get({RocksDb, table})
    :ok = :rocksdb.flush(db_ref, cf_ref, [])
  end

  defp property(table, name) do
    {db_ref, cf_ref} = :persistent_term.get({RocksDb, table})
    {:ok, value} = :rocksdb.get_property(db_ref, cf_ref, name)
    value
  end

  defp cache_property(table, name),
    do: table |> property("rocksdb.block-cache-#{name}") |> String.to_integer()

  # total size of the filter blocks in the table's SST files
  defp filter_size(table) do
    [size] =
      Regex.run(
        ~r/filter block size=(\d+)/,
        property(table, "rocksdb.aggregated-table-properties"),
        capture: :all_but_first
      )

    String.to_integer(size)
  end

  # options of a section of the OPTIONS file that RocksDB wrote on the last open
  defp options(config, section) do
    config[:data_dir]
    |> Path.join("OPTIONS-*")
    |> Path.wildcard()
    |> Enum.max()
    |> File.read!()
    |> String.split("\n")
    |> Enum.drop_while(&(&1 != "[#{section}]"))
    |> Enum.drop(1)
    |> Enum.take_while(&(not String.starts_with?(&1, "[")))
    |> Enum.flat_map(fn line ->
      case line |> String.trim() |> String.split("=", parts: 2) do
        [key, value] -> [{key, value}]
        [_blank] -> []
      end
    end)
    |> Map.new()
  end

  defp runtime_config(env) do
    previous = Map.new(@env_vars, &{&1, System.get_env(&1)})
    Enum.each(@env_vars, &System.delete_env/1)
    System.put_env(env)

    try do
      "config/runtime.exs"
      |> Config.Reader.read!(env: :prod)
      |> get_in([:ae_mdw, RocksDb])
      |> Map.new()
    after
      Enum.each(previous, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)
    end
  end
end

defmodule AeMdwWeb.Cache.GraphQLResponseCache do
  @moduledoc """
  Short-lived ETS response cache for GraphQL queries.

  Cache key: MD5 digest of the raw request body (query + variables together),
  so different variable bindings for the same query are cached separately.

  TTL is checked on each lookup against the `:graphql_response_cache_ttl_ms`
  application env key (default 5 000 ms). The ETS table itself is GC-ed every
  minute to reclaim memory from expired entries.

  Only successful (HTTP 200) responses are stored.
  """

  alias AeMdw.EtsCache

  @table :graphql_response_cache
  # Coarse GC interval; precise TTL is enforced per-lookup using the stored
  # insert timestamp (milliseconds since epoch, same as EtsCache.put/3).
  @gc_minutes 1

  @spec init() :: :ok
  def init do
    EtsCache.new(@table, @gc_minutes)
    :ok
  end

  @spec lookup(binary()) :: {:ok, iodata()} | :miss
  def lookup(key) do
    ttl_ms = Application.get_env(:ae_mdw, :graphql_response_cache_ttl_ms, 5_000)
    now = :os.system_time(:millisecond)

    case EtsCache.get(@table, key) do
      {body, insert_time} when now - insert_time <= ttl_ms -> {:ok, body}
      _ -> :miss
    end
  end

  @spec store(binary(), iodata()) :: :ok
  def store(key, body) do
    EtsCache.put(@table, key, body)
    :ok
  end
end

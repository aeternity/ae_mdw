defmodule AeMdwWeb.Plugs.GraphQLPlug do
  @moduledoc """
  Wrapper around Absinthe.Plug that adds:

  * **Document cache** -- GraphQLDocumentCache is the first document provider;
    it caches parsed+validated blueprints in ETS by raw query string so
    subsequent identical queries skip the parse/validate phases entirely.

  * **Response cache** -- full JSON response bodies are cached in ETS with a
    short TTL (default 5 s, tunable via GRAPHQL_RESPONSE_CACHE_TTL_MS).
    Cache key is derived from the query string and variables, so different
    variable bindings for the same operation are stored separately.

  * **Complexity limiting** -- maximum query complexity is enforced at runtime
    using the GRAPHQL_MAX_COMPLEXITY env var (default 1_000).

  Plug.Parsers is called once per request to decode the JSON body into
  conn.body_params. Absinthe.Plug.Request checks body_params["query"]
  first, so it never tries to re-read the already-consumed body stream.
  """

  @behaviour Plug

  alias AeMdwWeb.Cache.GraphQLDocumentCache
  alias AeMdwWeb.Cache.GraphQLResponseCache

  # Schema initialisation happens once at compile time.
  @base_opts Absinthe.Plug.init(schema: AeMdwWeb.GraphQL.Schema)

  # Static Absinthe opts – everything except max_complexity, which comes from
  # the Application environment set at runtime via runtime.exs. Pre-merged here
  # so each request only pays for a single Map.put instead of a full merge.
  @static_opts Map.merge(@base_opts, %{
                 analyze_complexity: true,
                 document_providers: [
                   GraphQLDocumentCache,
                   Absinthe.Plug.DocumentProvider.Default
                 ]
               })

  # Pre-built Plug.Parsers opts -- JSON only, no form data.
  @parsers_opts Plug.Parsers.init(parsers: [:json], json_decoder: Jason)

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    # Decode JSON body into body_params so Absinthe.Plug.Request can read the
    # query from there instead of attempting a second raw-body read.
    conn = parse_body(conn)

    cache_key = build_cache_key(conn)

    case cache_key && GraphQLResponseCache.lookup(cache_key) do
      {:ok, cached_body} ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, cached_body)
        |> Plug.Conn.halt()

      _other ->
        conn
        |> maybe_register_cache_write(cache_key)
        |> Absinthe.Plug.call(runtime_opts())
    end
  end

  # ---------------------------------------------------------------------------

  # Parse the body for application/json requests; pass through for everything
  # else (application/graphql bodies are read directly by Absinthe).
  # Errors from malformed JSON are swallowed so Absinthe can return a proper
  # GraphQL error response.
  defp parse_body(conn) do
    try do
      conn
      |> Plug.Parsers.call(@parsers_opts)
      |> Plug.Conn.fetch_query_params()
      |> sync_body_params_into_params()
    rescue
      Plug.Parsers.ParseError -> conn
      Plug.Parsers.UnsupportedMediaTypeError -> conn
    end
  end

  defp sync_body_params_into_params(
         %{body_params: %{} = body_params, params: %{} = params} = conn
       ) do
    %{conn | params: Map.merge(params, body_params)}
  end

  # Build a stable cache key from the normalised {query, operationName,
  # variables} triple so that JSON-formatting differences in the raw body do
  # not cause cache misses, while distinct named operations on the same
  # document stay isolated.
  # Returns nil for non-JSON requests, which disables the response cache for
  # that request (application/graphql requests still benefit from the document
  # cache).
  defp build_cache_key(%{body_params: %{"query" => query} = body_params}) do
    operation_name = Map.get(body_params, "operationName")
    variables = Map.get(body_params, "variables", %{})
    :crypto.hash(:md5, :erlang.term_to_binary({query, operation_name, variables}))
  end

  defp build_cache_key(_conn), do: nil

  defp maybe_register_cache_write(conn, nil), do: conn

  defp maybe_register_cache_write(conn, cache_key) do
    Plug.Conn.register_before_send(conn, fn conn ->
      # GraphQL always returns HTTP 200, even for errors — the actual error
      # information lives in the top-level "errors" key. We must not cache error
      # responses, or a transient error (e.g. account-not-found) would block
      # correct responses for the full TTL.
      with 200 <- conn.status,
           {:ok, body} <- Jason.decode(conn.resp_body),
           false <- match?(%{"errors" => [_ | _]}, body) do
        GraphQLResponseCache.store(cache_key, conn.resp_body)
      end

      conn
    end)
  end

  defp runtime_opts do
    Map.put(
      @static_opts,
      :max_complexity,
      Application.get_env(:ae_mdw, :graphql_max_complexity, 1_000)
    )
  end
end

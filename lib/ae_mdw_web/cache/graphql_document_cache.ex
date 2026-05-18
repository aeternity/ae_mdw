defmodule AeMdwWeb.Cache.GraphQLDocumentCache do
  @moduledoc """
  Absinthe.Plug document provider that caches parsed and structurally-validated
  query blueprints in ETS, keyed by the raw query string.

  The compilation pipeline runs parse + structural-validation phases, stopping
  just before `Absinthe.Phase.Document.Context`. This means the cached blueprint
  does not embed a request-specific execution context, so it can be safely
  reused across requests with different context maps and variable bindings.
  The runtime `pipeline/1` callback resumes from `Phase.Document.Context`,
  which applies the per-request context, followed by variable substitution
  and full execution.

  Since the GraphQL schema is compiled and fixed at startup, cached blueprints
  are valid for the lifetime of the node process — no TTL is needed.
  """

  @behaviour Absinthe.Plug.DocumentProvider

  @table :graphql_document_cache

  # Hard cap on the number of cached blueprints. Once reached, new unique
  # queries bypass the cache (still execute normally). Prevents unbounded ETS
  # growth from adversarially varied query strings.
  @max_cached_documents 1_000

  # Phases executed at "compile" time (parsing + structural validation only).
  # Stops before the Context phase so the cached blueprint does not contain
  # a request-specific execution context, allowing it to be reused across
  # requests with different context maps and variable bindings.
  @resume_phase Absinthe.Phase.Document.Context

  @spec init() :: :ok
  def init do
    _ = :ets.new(@table, [:named_table, :set, :public, {:read_concurrency, true}])
    :ok
  end

  @impl Absinthe.Plug.DocumentProvider
  def pipeline(%{pipeline: as_configured}) do
    Absinthe.Pipeline.from(as_configured, @resume_phase)
  end

  @impl Absinthe.Plug.DocumentProvider
  def process(%{document: source} = query, _opts) when is_binary(source) do
    case :ets.lookup(@table, source) do
      [{^source, blueprint}] ->
        {:halt, %{query | document: blueprint}}

      [] ->
        compilation_pipeline =
          query.schema
          |> Absinthe.Pipeline.for_document()
          |> Absinthe.Pipeline.before(@resume_phase)

        case Absinthe.Pipeline.run(source, compilation_pipeline) do
          {:ok, blueprint, _phases} ->
            if :ets.info(@table, :size) < @max_cached_documents do
              :ets.insert(@table, {source, blueprint})
            end

            {:halt, %{query | document: blueprint}}

          _error ->
            {:cont, query}
        end
    end
  end

  def process(query, _opts), do: {:cont, query}
end

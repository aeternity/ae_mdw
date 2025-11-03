defmodule AeMdwWeb.GraphQL.Schema.Types.OracleTypes do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros
  require Macros

  enum :oracle_state do
    value(:active)
    value(:inactive)
  end

  object :oracle_format do
    field(:query, :string)
    field(:response, :string)
  end

  Macros.page(:oracle)

  object :oracle do
    field(:oracle, :string)
    field(:active, :boolean)
    field(:active_from, :integer)
    field(:register_time, :integer)
    field(:expire_height, :integer)
    field(:approximate_expire_time, :integer)
    field(:register_tx_hash, :string)
    field(:query_fee, :big_int)
    field(:format, :oracle_format)
  end

  Macros.page(:oracle_query)

  object :oracle_query do
    field(:height, :integer)
    field(:block_hash, :string)
    field(:block_time, :integer)
    field(:source_tx_hash, :string)
    field(:source_tx_type, :string)
    field(:query_id, :string)
    # Base64 encoded query payload
    field(:query, :string)
    # When present, the associated response for this query
    field(:response, :oracle_response)
  end

  Macros.page(:oracle_response)

  object :oracle_response do
    field(:height, :integer)
    field(:block_hash, :string)
    field(:block_time, :integer)
    field(:source_tx_hash, :string)
    field(:source_tx_type, :string)
    field(:query_id, :string)
    # Base64 encoded response payload
    field(:response, :string)
    # When present, the originating query for this response
    field(:query, :oracle_query)
  end

  Macros.page(:oracle_extend)

  object :oracle_extend do
    field(:height, :integer)
    field(:block_hash, :string)
    field(:source_tx_hash, :string)
    field(:source_tx_type, :string)
    field(:tx, :json)
  end
end

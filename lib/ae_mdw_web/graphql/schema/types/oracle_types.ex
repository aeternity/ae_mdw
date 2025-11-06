defmodule AeMdwWeb.GraphQL.Schema.Types.OracleTypes do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros
  require Macros

  enum :oracle_state do
    value(:active)
    value(:inactive)
  end

  Macros.page(:oracle)

  object :oracle do
    field(:active, :boolean)
    field(:register, :json)
    field(:format, :json)
    field(:oracle, :string)
    field(:query_fee, :big_int)
    field(:expire_height, :integer)
    field(:active_from, :integer)
    field(:approximate_expire_time, :integer)
    field(:register_time, :integer)
    field(:register_tx_hash, :string)
  end

  Macros.page(:oracle_query)

  object :oracle_query do
    field(:response, :oracle_response)
    field(:height, :integer)
    field(:block_hash, :string)
    field(:query_id, :string)
    field(:block_time, :integer)
    field(:source_tx_hash, :string)
    field(:source_tx_type, :string)
    field(:fee, :big_int)
    field(:nonce, :integer)
    field(:oracle_id, :string)
    field(:query, :string)
    field(:query_fee, :big_int)
    field(:query_ttl, :json)
    field(:response_ttl, :json)
    field(:sender_id, :string)
    field(:ttl, :integer)
  end

  Macros.page(:oracle_response)

  object :oracle_response do
    field(:height, :integer)
    field(:block_hash, :string)
    field(:query_id, :string)
    field(:block_time, :integer)
    field(:source_tx_hash, :string)
    field(:source_tx_type, :string)
    field(:fee, :big_int)
    field(:nonce, :integer)
    field(:oracle_id, :string)
    field(:response, :string)
    field(:response_ttl, :json)
    field(:ttl, :integer)
  end

  # Macros.page(:oracle_extend)

  # object :oracle_extend do
  #  field(:height, :integer)
  #  field(:block_hash, :string)
  #  field(:source_tx_hash, :string)
  #  field(:source_tx_type, :string)
  #  field(:tx, :json)
  # end
end

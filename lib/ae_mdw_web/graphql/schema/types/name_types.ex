defmodule AeMdwWeb.GraphQL.Schema.Types.NameTypes do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros

  require Macros

  enum :name_state do
    value(:active)
    value(:inactive)
  end

  enum :name_order do
    value(:expiration)
    value(:activation)
    value(:deactivation)
    value(:name)
  end

  enum :auction_order do
    value(:expiration)
    value(:name)
  end

  Macros.page(:name)

  object :name do
    field(:active, :boolean)
    field(:name, :string)
    field(:hash, :string)
    field(:name_fee, :big_int)
    # TODO: make sure this is the right type
    field(:pointers, list_of(:json))
    # TODO: make sure this is the right type
    field(:revoke, :string)
    field(:expire_height, :integer)
    field(:claims_count, :integer)
    field(:auction_timeout, :integer)
    # TODO: make sure this is the right type
    field(:auction, :string)
    field(:active_from, :integer)
    field(:approximate_expire_time, :integer)
    field(:ownership, :json)
    field(:approximate_activation_time, :integer)
  end

  Macros.page(:name_claim)

  object :name_claim do
    field(:height, :integer)
    field(:block_hash, :string)
    field(:tx, :json)
    field(:active_from, :integer)
    field(:internal_source, :boolean)
    field(:source_tx_hash, :string)
    field(:source_tx_type, :string)
  end

  Macros.page(:name_update)

  # TODO: verify fields and types
  object :name_update do
    field(:height, :integer)
    field(:block_hash, :string)
    field(:tx, :json)
    field(:active_from, :integer)
    field(:internal_source, :boolean)
    field(:source_tx_hash, :string)
    field(:source_tx_type, :string)
  end

  Macros.page(:name_transfer)

  # TODO: verify fields and types
  object :name_transfer do
    field(:height, :integer)
    field(:block_hash, :string)
    field(:tx, :json)
    field(:active_from, :integer)
    field(:internal_source, :boolean)
    field(:source_tx_hash, :string)
    field(:source_tx_type, :string)
  end

  Macros.page(:name_history)

  # TODO: verify fields and types
  object :name_history do
    field(:height, :integer)
    field(:block_hash, :string)
    field(:tx, :json)
    field(:active_from, :integer)
    field(:expired_at, :integer)
    field(:internal_source, :boolean)
    field(:source_tx_hash, :string)
    field(:source_tx_type, :string)
  end

  Macros.page(:auction)

  object :auction do
    field(:name, :string)
    field(:name_fee, :big_int)
    field(:claims_count, :integer)
    field(:approximate_expire_time, :integer)
    field(:last_bid, :json)
    field(:auction_end, :integer)
    field(:activation_time, :integer)
  end
end

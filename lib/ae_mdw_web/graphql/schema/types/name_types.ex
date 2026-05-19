defmodule AeMdwWeb.GraphQL.Schema.Types.NameTypes do
  @moduledoc false

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
    field(:type, :string)
    field(:hash, :string)
    field(:name_fee, :big_int)
    field(:pointers, list_of(:json))
    field(:revoke, :json)
    field(:expire_height, :integer)
    field(:claims_count, :integer)
    field(:auction_timeout, :integer)
    field(:auction, :json)
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

  # name_update, name_transfer, name_history share the same render shape
  # from Names.render_nested_resource/2
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

  Macros.page(:pointee)

  object :pointee do
    field(:active, :boolean)
    field(:name, :string)
    field(:key, :string)
    field(:block_hash, :string)
    field(:tx, :json)
    field(:block_height, :integer)
    field(:block_time, :integer)
    field(:source_tx_hash, :string)
    field(:source_tx_type, :string)
  end
end

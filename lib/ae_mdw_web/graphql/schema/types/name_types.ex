defmodule AeMdwWeb.GraphQL.Schema.Types.NameTypes do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros
  require Macros

  Macros.page(:name)

  object :name do
    field(:name, :string)
    field(:active, :boolean)
    field(:expire_height, :integer)
    field(:hash, :string)
    field(:active_from, :integer)
    field(:approximate_activation_time, :integer)
    field(:approximate_expire_time, :integer)
    field(:name_fee, :integer)
    field(:claims_count, :integer)
    field(:auction_timeout, :integer)

    field(:revoke, :string,
      description: "Revoke transaction (tx hash or expanded JSON if expand requested)"
    )

    field(:pointers, list_of(:name_pointer))
    field(:ownership, :name_ownership)
    field(:auction, :string, description: "Auction data (JSON string) if still in auction")
  end

  Macros.page(:name_history_page, :name_history_item)

  object :name_history_item do
    field(:active_from, :integer)
    field(:expired_at, :integer)
    field(:height, :integer)
    field(:block_hash, :string)
    field(:source_tx_hash, :string)
    field(:source_tx_type, :string)
    field(:internal_source, :boolean)
    field(:tx, :string, description: "Source chain transaction (JSON)")
  end

  Macros.page(:auction)

  object :auction do
    field(:name, :string)
    field(:activation_time, :integer)
    field(:auction_end, :integer)
    field(:approximate_expire_time, :integer)
    field(:name_fee, :integer)
    field(:claims_count, :integer)
    field(:last_bid, :string, description: "JSON with last bid tx")
  end

  Macros.page(:search_name_page, :search_name_entry)

  object :search_name_entry do
    field(:type, :string)
    field(:name, :string)
    field(:active, :boolean)
    field(:auction, :auction)
  end

  Macros.page(:pointee)

  object :pointee do
    field(:name, :string)
    field(:active, :boolean)
    field(:key, :string)
    field(:block_height, :integer)
    field(:block_hash, :string)
    field(:block_time, :integer)
    field(:source_tx_hash, :string)
    field(:source_tx_type, :string)
    field(:tx, :string)
  end

  object :name_pointees do
    field(:active, list_of(:name_pointer))
    field(:inactive, list_of(:name_pointer))
  end

  object :name_pointer do
    field(:key, :string)
    field(:id, :string)
  end

  object :name_ownership do
    field(:current, :string)
    field(:original, :string)
  end

  enum :auction_order do
    value(:expiration)
    value(:name)
  end

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
end

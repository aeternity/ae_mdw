defmodule AeMdwWeb.GraphQL.Schema.Types.ChannelTypes do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros
  require Macros

  enum :channel_state do
    value(:active)
    value(:inactive)
  end

  Macros.page(:channel)

  object :channel do
    field(:channel, :string)
    field(:initiator, :string)
    field(:responder, :string)
    field(:state_hash, :string)
    field(:last_updated_height, :integer)
    field(:last_updated_time, :integer)
    field(:last_updated_tx_hash, :string)
    field(:last_updated_tx_type, :string)
    field(:updates_count, :integer)
    field(:active, :boolean)
    field(:amount, :big_int)
    # Extra node details if available (balances, deposits, etc.) are flattened into this object
    field(:round, :integer)
  end

  Macros.page(:channel_update)

  object :channel_update do
    field(:channel, :string)
    field(:tx_type, :string)
    field(:block_hash, :string)
    field(:source_tx_hash, :string)
    field(:source_tx_type, :string)
    field(:tx, :json)
  end
end

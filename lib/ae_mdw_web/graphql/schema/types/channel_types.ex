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
    field(:active, :boolean)
    field(:channel, :string)
    field(:amount, :big_int)
    field(:responder, :string)
    field(:initiator, :string)
    field(:state_hash, :string)
    field(:last_updated_height, :integer)
    field(:last_updated_time, :integer)
    field(:last_updated_tx_hash, :string)
    field(:last_updated_tx_type, :string)
    field(:updates_count, :integer)
    field(:channel_reserve, :big_int)
    field(:delegate_ids, :json)
    field(:initiator_amount, :big_int)
    field(:lock_period, :integer)
    field(:locked_until, :integer)
    field(:responder_amount, :big_int)
    field(:round, :integer)
    field(:solo_round, :integer)
  end

  Macros.page(:channel_update)

  object :channel_update do
    field(:channel, :string)
    field(:block_hash, :string)
    field(:tx, :json)
    field(:tx_type, :string)
    field(:source_tx_hash, :string)
    field(:source_tx_type, :string)
  end
end

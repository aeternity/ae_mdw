defmodule AeMdwWeb.GraphQL.Schema.Types.Aex9Types do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros
  require Macros

  enum :aex9_contract_order_by do
    value(:creation, description: "Sort by creation time")
    value(:name, description: "Sort by name")
    value(:symbol, description: "Sort by symbol")
  end

  # TODO: make sure these are all the possible values for this enum
  enum :aex9_balance_order_by do
    value(:pubkey)
    value(:amount)
  end

  Macros.page(:aex9_contract)

  object :aex9_contract do
    field(:decimals, :integer)
    field(:invalid, :boolean)
    field(:name, :string)
    field(:extensions, list_of(:string))
    field(:symbol, :string)
    field(:contract_id, :string)
    field(:contract_tx_hash, :string)
    # TODO: make sure this is the right type
    field(:invalid_description, :string)
    # TODO: make sure this is the right type
    field(:invalid_reason, :string)
    field(:event_supply, :big_int)
    field(:holders, :integer)
    field(:initial_supply, :big_int)
    field(:logs_count, :integer)
  end

  Macros.page(:aex9_contract_balance)

  object :aex9_contract_balance do
    field(:height, :integer)
    field(:amount, :big_int)
    field(:contract_id, :string)
    field(:block_hash, :string)
    field(:account_id, :string)
    field(:last_tx_hash, :string)
    field(:last_log_idx, :integer)
  end

  Macros.page(:aex9_balance_history_item)

  object :aex9_balance_history_item do
    field(:contract, :string)
    field(:account, :string)
    field(:height, :integer)
    field(:amount, :big_int)
  end

  Macros.page(:aex9_transfer)

  object :aex9_transfer do
    field(:amount, :big_int)
    field(:contract_id, :string)
    field(:recipient, :string)
    field(:tx_hash, :string)
    field(:sender, :string)
    field(:block_height, :integer)
    field(:log_idx, :integer)
    field(:micro_index, :integer)
    field(:micro_time, :integer)
  end
end

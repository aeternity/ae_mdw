defmodule AeMdwWeb.GraphQL.Schema.Types.Aex9Types do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros
  require Macros

  @desc "Ordering options for AEX9 contract balances"
  enum :aex9_balance_order_by do
    value(:pubkey)
    value(:amount)
  end

  Macros.page(:aex9_contract)

  @desc "AEX9 token contract"
  object :aex9_contract do
    field(:contract_id, non_null(:string))
    field(:contract_tx_hash, :string)
    field(:name, :string)
    field(:symbol, :string)
    field(:decimals, :integer)
    field(:extensions, list_of(:string))
    field(:initial_supply, :big_int)
    field(:event_supply, :big_int)
    field(:holders, :integer)
    field(:invalid, :boolean)
    field(:invalid_reason, :string)
    field(:invalid_description, :string)
    field(:logs_count, :integer)
  end

  Macros.page(:aex9_contract_balance)

  @desc "Balance entry within an AEX9 contract"
  object :aex9_contract_balance do
    field(:contract_id, :string)
    field(:account_id, :string)
    field(:block_hash, :string)
    field(:height, :integer)
    field(:last_tx_hash, :string)
    field(:last_log_idx, :integer)
    field(:amount, :big_int)
  end

  Macros.page(:aex9_balance_history_item)

  @desc "Historical balance point for an account on an AEX9 contract"
  object :aex9_balance_history_item do
    # Note: backend returns keys as `contract` and `account`; we normalize via resolver
    field(:contract_id, :string)
    field(:account_id, :string)
    field(:height, :integer)
    field(:amount, :big_int)
  end

  Macros.page(:aex9_transfer)

  @desc "AEX9 transfer event"
  object :aex9_transfer do
    field(:amount, :big_int)
    field(:block_height, :integer)
    field(:micro_index, :integer)
    field(:micro_time, :integer)
    field(:contract_id, :string)
    field(:log_idx, :integer)
    field(:tx_hash, :string)
    field(:sender, :string)
    field(:recipient, :string)
    # present for some endpoints (non-v3 rendering)
    field(:call_txi, :integer)
  end
end

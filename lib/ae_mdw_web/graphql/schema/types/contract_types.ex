defmodule AeMdwWeb.GraphQL.Schema.Types.ContractTypes do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros
  require Macros

  Macros.page(:contract)

  object :contract do
    field(:contract, :string)
    field(:block_hash, :string)
    field(:create_tx, :json)
    field(:aexn_type, :string)
    field(:source_tx_hash, :string)
    field(:source_tx_type, :string)
  end

  Macros.page(:contract_log)

  object :contract_log do
    field(:args, list_of(:string))
    field(:data, :string)
    field(:height, :integer)
    field(:contract_id, :string)
    field(:block_hash, :string)
    field(:event_name, :string)
    field(:log_idx, :integer)
    field(:block_time, :integer)
    field(:call_tx_hash, :string)
    field(:contract_tx_hash, :string)
    field(:micro_index, :integer)
    field(:event_hash, :string)
    field(:ext_caller_contract_id, :string)
    field(:ext_caller_contract_tx_hash, :string)
    field(:parent_contract_id, :string)
  end

  Macros.page(:contract_call)

  object :contract_call do
    field(:function, :string)
    field(:height, :integer)
    field(:contract_id, :string)
    field(:block_hash, :string)
    field(:call_tx_hash, :string)
    field(:contract_tx_hash, :string)
    field(:internal_tx, :json)
    field(:local_idx, :integer)
    field(:micro_index, :integer)
  end
end

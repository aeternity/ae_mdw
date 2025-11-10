defmodule AeMdwWeb.GraphQL.Schema.Types.Aex141Types do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros
  require Macros

  # TODO: duplicated enum in aex9_types.ex
  enum :aex141_contract_order_by do
    value(:creation, description: "Sort by creation time")
    value(:name, description: "Sort by name")
    value(:symbol, description: "Sort by symbol")
  end

  Macros.page(:aex141_contract)

  object :aex141_contract do
    field(:invalid, :boolean)
    field(:name, :string)
    field(:extensions, list_of(:string))
    field(:symbol, :string)
    field(:contract_id, :string)
    field(:block_height, :integer)
    field(:creation_time, :integer)
    field(:nft_owners, :integer)
    field(:nfts_amount, :integer)
    field(:contract_tx_hash, :string)
    # TODO: make sure this has the right type
    field(:invalid_reason, :string)
    # TODO: make sure this has the right type
    field(:invalid_description, :string)
    # TODO: make sure this has the right type
    field(:base_url, :string)
    field(:limits, :json)
    field(:metadata_type, :string)
  end

  Macros.page(:aex141_transfer)

  object :aex141_transfer do
    field(:contract_id, :string)
    field(:recipient, :string)
    field(:tx_hash, :string)
    field(:sender, :string)
    field(:block_height, :integer)
    field(:log_idx, :integer)
    field(:call_txi, :integer)
    field(:micro_index, :integer)
    field(:micro_time, :integer)
    field(:token_id, :integer)
  end

  Macros.page(:aex141_token)

  object :aex141_token do
    field(:owner_id, :string)
    field(:contract_id, :string)
    field(:token_id, :integer)
  end

  object :aex141_token_with_metadata do
    field(:owner, :string)
    field(:metadata, :json)
    field(:contract_id, :string)
    field(:token_id, :integer)
  end
end

defmodule AeMdwWeb.GraphQL.Schema.Types.Aex141Types do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros
  require Macros

  Macros.page(:aex141_contract)

  @desc "Limits info for an AEX141 contract"
  object :aex141_limits do
    field(:token_limit, :integer)
    field(:template_limit, :integer)
    field(:limit_tx_hash, :string)
    field(:limit_log_idx, :integer)
  end

  @desc "AEX141 NFT contract"
  object :aex141_contract do
    field(:contract_id, non_null(:string))
    field(:contract_tx_hash, :string)
    field(:name, :string)
    field(:symbol, :string)
    field(:base_url, :string)
    field(:metadata_type, :string)
    field(:extensions, list_of(:string))
    field(:limits, :aex141_limits)
    field(:creation_time, :integer)
    field(:block_height, :integer)
    field(:nft_owners, :integer)
    field(:nfts_amount, :integer)
    field(:invalid, :boolean)
    field(:invalid_reason, :string)
    field(:invalid_description, :string)
  end

  Macros.page(:aex141_token_owner)

  @desc "NFT ownership entry"
  object :aex141_token_owner do
    field(:contract_id, :string)
    field(:owner_id, :string)
    field(:token_id, :integer)
  end

  Macros.page(:aex141_template)

  @desc "AEX141 template info"
  object :aex141_template do
    field(:contract_id, :string)
    field(:template_id, :integer)
    field(:tx_hash, :string)
    field(:log_idx, :integer)
    field(:edition, :json)
  end

  Macros.page(:aex141_template_token)

  @desc "AEX141 token minted from a template"
  object :aex141_template_token do
    field(:token_id, :integer)
    field(:owner_id, :string)
    field(:tx_hash, :string)
    field(:log_idx, :integer)
    field(:edition, :json)
  end

  Macros.page(:aex141_transfer)

  @desc "AEX141 transfer event"
  object :aex141_transfer do
    field(:token_id, :integer)
    field(:block_height, :integer)
    field(:micro_index, :integer)
    field(:micro_time, :integer)
    field(:contract_id, :string)
    field(:log_idx, :integer)
    field(:tx_hash, :string)
    field(:sender, :string)
    field(:recipient, :string)
    field(:call_txi, :integer)
  end

  @desc "Detailed NFT (with metadata)"
  object :aex141_token_detail do
    field(:contract_id, :string)
    field(:token_id, :integer)
    field(:owner_id, :string)
    field(:metadata, :json)
  end
end

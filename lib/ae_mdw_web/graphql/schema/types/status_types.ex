defmodule AeMdwWeb.GraphQL.Schema.Types.StatusTypes do
  @moduledoc false

  use Absinthe.Schema.Notation

  object :status do
    field(:node_height, :integer)
    field(:node_version, :string)
    field(:mdw_async_tasks, :json)
    field(:mdw_gens_per_minute, :float)
    field(:mdw_height, :integer)
    field(:mdw_last_migration, :integer)
    field(:mdw_revision, :string)
    field(:mdw_synced, :boolean)
    field(:mdw_syncing, :boolean)
    field(:mdw_tx_index, :integer)
    field(:mdw_version, :string)
    field(:node_progress, :float)
    field(:node_revision, :string)
    field(:node_syncing, :boolean)
    field(:partial, :boolean)
    field(:last_synced_height, :integer)
    field(:last_key_block_hash, :string)
    field(:last_key_block_time, :integer)
    field(:total_transactions, :integer)
    field(:pending_transactions, :integer)
  end

  object :sync_status do
    field(:last_synced_height, :integer)
    field(:partial, :boolean)
  end
end

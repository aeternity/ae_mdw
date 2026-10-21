defmodule AeMdwWeb.GraphQL.Schema.Types.MinerStatsTypes do
  @moduledoc false

  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros

  require Macros

  enum :miner_role do
    value(:miner)
    value(:beneficiary)
  end

  enum :miners_order do
    value(:blocks)
    value(:txs)
    value(:rewards)
    value(:fees)
    value(:first_active)
    value(:last_active)
  end

  object :mining_summary do
    field(:bucket_size, :integer)
    field(:mdw_height, :integer)
    field(:stats_height, :integer)
    field(:last_bucket, :integer)
    field(:blocks, :integer)
    field(:txs, :integer)
    field(:rewards, :big_int)
    field(:fees, :big_int)
    field(:miners, :integer)
    field(:beneficiaries, :integer)
  end

  Macros.page(:miner_entity)

  object :miner_entity do
    field(:id, :string)
    field(:role, :string)
    field(:first_height, :integer)
    field(:first_time, :integer)
    field(:last_height, :integer)
    field(:last_time, :integer)
    field(:blocks, :integer)
    field(:txs, :integer)
    field(:rewards, :big_int)
    field(:fees, :big_int)
    field(:last_info, :integer)
    field(:info_changes, :integer)
  end

  Macros.page(:miner_link)

  object :miner_link do
    field(:id, :string)
    field(:role, :string)
    field(:blocks, :integer)
    field(:first_height, :integer)
    field(:last_height, :integer)
  end

  Macros.page(:miner_series_row)

  object :miner_series_row do
    field(:id, :string)
    field(:bucket, :integer)
    field(:interval, :integer)
    field(:start_height, :integer)
    field(:end_height, :integer)
    field(:start_time, :integer)
    field(:end_time, :integer)
    field(:blocks, :integer)
    field(:txs, :integer)
    field(:rewards, :big_int)
    field(:fees, :big_int)
    field(:blocks_total, :integer)
    field(:txs_total, :integer)
    field(:rewards_total, :big_int)
    field(:fees_total, :big_int)
  end

  Macros.page(:mining_series_row)

  object :mining_series_row do
    field(:bucket, :integer)
    field(:interval, :integer)
    field(:start_height, :integer)
    field(:end_height, :integer)
    field(:start_time, :integer)
    field(:end_time, :integer)
    field(:blocks, :integer)
    field(:micro_blocks, :integer)
    field(:txs, :integer)
    field(:rewards, :big_int)
    field(:fees, :big_int)
    field(:avg_block_time, :integer)
    field(:avg_difficulty, :big_int)
    field(:hashrate, :big_int)
    field(:active_miners, :integer)
    field(:active_beneficiaries, :integer)
    field(:new_miners, :integer)
    field(:new_beneficiaries, :integer)
    field(:top_miner_blocks, :integer)
    field(:top_beneficiary_blocks, :integer)
    field(:blocks_total, :integer)
    field(:txs_total, :integer)
    field(:rewards_total, :big_int)
    field(:fees_total, :big_int)
    field(:miners_total, :integer)
    field(:beneficiaries_total, :integer)
  end
end

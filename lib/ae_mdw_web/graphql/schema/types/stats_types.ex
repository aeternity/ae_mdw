defmodule AeMdwWeb.GraphQL.Schema.Types.StatsTypes do
  use Absinthe.Schema.Notation

  alias AeMdwWeb.GraphQL.Schema.Helpers.Macros
  require Macros

  enum :stats_interval do
    value(:day)
    value(:week)
    value(:month)
  end

  enum :block_type do
    value(:key)
    value(:micro)
  end

  object :stats do
    field(:total_blocks, :integer)
    field(:fees_trend, :float)
    field(:last24hs_average_transaction_fees, :float)
    field(:last24hs_transactions, :integer)
    field(:max_transactions_per_second, :float)
    field(:max_transactions_per_second_block_hash, :string)
    field(:milliseconds_per_block, :integer)
    field(:transactions_trend, :float)
    field(:miners_count, :integer)
  end

  Macros.page(:start_end_count_stats)

  object :start_end_count_stats do
    field(:count, :integer)
    field(:start_date, :string)
    field(:end_date, :string)
  end

  Macros.page(:total_stats)

  object :total_stats do
    field(:height, :integer)
    field(:contracts, :integer)
    field(:locked_in_auctions, :big_int)
    field(:burned_in_auctions, :big_int)
    field(:locked_in_channels, :big_int)
    field(:active_auctions, :integer)
    field(:active_names, :integer)
    field(:inactive_names, :integer)
    field(:active_oracles, :integer)
    field(:inactive_oracles, :integer)
    field(:open_channels, :integer)
    field(:last_tx_hash, :string)
    field(:sum_block_reward, :big_int)
    field(:sum_dev_reward, :big_int)
    field(:total_token_supply, :big_int)
  end

  Macros.page(:delta_stats)

  object :delta_stats do
    field(:height, :integer)
    field(:auctions_started, :integer)
    field(:names_activated, :integer)
    field(:names_expired, :integer)
    field(:names_revoked, :integer)
    field(:oracles_registered, :integer)
    field(:oracles_expired, :integer)
    field(:contracts_created, :integer)
    field(:block_reward, :big_int)
    field(:dev_reward, :big_int)
    field(:locked_in_auctions, :big_int)
    field(:burned_in_auctions, :big_int)
    field(:channels_opened, :integer)
    field(:channels_closed, :integer)
    field(:locked_in_channels, :big_int)
    field(:last_tx_hash, :string)
  end

  Macros.page(:miners_stats)

  object :miners_stats do
    field(:miner, :string)
    field(:total_reward, :big_int)
  end

  Macros.page(:top_miners_stats)

  object :top_miners_stats do
    field(:miner, :string)
    field(:blocks_mined, :integer)
    field(:start_date, :string)
    field(:end_date, :string)
  end

  object :top_miners_24h_stats do
    field(:miner, :string)
    field(:blocks_mined, :integer)
  end

  object :top_miners_24h_stats_page do
    field(:data, list_of(:top_miners_24h_stats))
  end
end

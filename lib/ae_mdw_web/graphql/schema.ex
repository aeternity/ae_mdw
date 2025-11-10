defmodule AeMdwWeb.GraphQL.Schema do
  use Absinthe.Schema

  import_types(AeMdwWeb.GraphQL.Schema.Helpers.CustomTypes)

  import_types(AeMdwWeb.GraphQL.Schema.Types.AccountTypes)
  import_types(AeMdwWeb.GraphQL.Schema.Types.BlockTypes)
  import_types(AeMdwWeb.GraphQL.Schema.Types.ContractTypes)
  import_types(AeMdwWeb.GraphQL.Schema.Types.NameTypes)
  import_types(AeMdwWeb.GraphQL.Schema.Types.StatsTypes)
  import_types(AeMdwWeb.GraphQL.Schema.Types.StatusTypes)
  import_types(AeMdwWeb.GraphQL.Schema.Types.TransactionTypes)
  import_types(AeMdwWeb.GraphQL.Schema.Types.ChannelTypes)
  import_types(AeMdwWeb.GraphQL.Schema.Types.Aex9Types)
  import_types(AeMdwWeb.GraphQL.Schema.Types.Aex141Types)
  import_types(AeMdwWeb.GraphQL.Schema.Types.OracleTypes)
  import_types(AeMdwWeb.GraphQL.Schema.Types.DexTypes)
  import_types(AeMdwWeb.GraphQL.Schema.Types.TransferTypes)

  import_types(AeMdwWeb.GraphQL.Schema.Queries.AccountQueries)
  import_types(AeMdwWeb.GraphQL.Schema.Queries.BlockQueries)
  import_types(AeMdwWeb.GraphQL.Schema.Queries.ContractQueries)
  import_types(AeMdwWeb.GraphQL.Schema.Queries.NameQueries)
  import_types(AeMdwWeb.GraphQL.Schema.Queries.StatsQueries)
  import_types(AeMdwWeb.GraphQL.Schema.Queries.StatusQueries)
  import_types(AeMdwWeb.GraphQL.Schema.Queries.TransactionQueries)
  import_types(AeMdwWeb.GraphQL.Schema.Queries.ChannelQueries)
  import_types(AeMdwWeb.GraphQL.Schema.Queries.Aex9Queries)
  import_types(AeMdwWeb.GraphQL.Schema.Queries.Aex141Queries)
  import_types(AeMdwWeb.GraphQL.Schema.Queries.OracleQueries)
  import_types(AeMdwWeb.GraphQL.Schema.Queries.DexQueries)
  import_types(AeMdwWeb.GraphQL.Schema.Queries.TransferQueries)

  query do
    import_fields(:account_queries)
    import_fields(:block_queries)
    import_fields(:contract_queries)
    import_fields(:name_queries)
    import_fields(:stat_queries)
    import_fields(:status_queries)
    import_fields(:transaction_queries)
    import_fields(:channel_queries)
    import_fields(:aex9_queries)
    import_fields(:aex141_queries)
    import_fields(:oracle_queries)
    import_fields(:dex_queries)
    import_fields(:transfer_queries)
  end
end

defmodule AeMdwWeb.GraphQL.Schema do
  use Absinthe.Schema

  import_types(AeMdwWeb.GraphQL.Schema.Helpers.CustomTypes)

  import_types(AeMdwWeb.GraphQL.Schema.Types.AccountTypes)
  import_types(AeMdwWeb.GraphQL.Schema.Types.BlockTypes)
  import_types(AeMdwWeb.GraphQL.Schema.Types.NameTypes)
  import_types(AeMdwWeb.GraphQL.Schema.Types.StatsTypes)
  import_types(AeMdwWeb.GraphQL.Schema.Types.StatusTypes)
  import_types(AeMdwWeb.GraphQL.Schema.Types.TransactionTypes)

  import_types(AeMdwWeb.GraphQL.Schema.Queries.AccountQueries)
  import_types(AeMdwWeb.GraphQL.Schema.Queries.BlockQueries)
  import_types(AeMdwWeb.GraphQL.Schema.Queries.NameQueries)
  import_types(AeMdwWeb.GraphQL.Schema.Queries.StatsQueries)
  import_types(AeMdwWeb.GraphQL.Schema.Queries.StatusQueries)
  import_types(AeMdwWeb.GraphQL.Schema.Queries.TransactionQueries)

  query do
    import_fields(:account_queries)
    import_fields(:block_queries)
    import_fields(:name_queries)
    import_fields(:stat_queries)
    import_fields(:status_queries)
    import_fields(:transaction_queries)
  end
end

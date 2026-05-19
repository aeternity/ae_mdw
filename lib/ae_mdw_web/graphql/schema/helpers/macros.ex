defmodule AeMdwWeb.GraphQL.Schema.Helpers.Macros do
  @moduledoc false

  # Matches the resolver default in AeMdwWeb.GraphQL.Resolvers.Helpers.
  @default_limit 10

  defmacro pagination_args() do
    default_limit = @default_limit
    base_pagination_ast(default_limit)
  end

  defmacro pagination_args_with_scope() do
    default_limit = @default_limit

    quote do
      unquote(base_pagination_ast(default_limit))
      arg(:from_height, :integer)
      arg(:to_height, :integer)
    end
  end

  defp base_pagination_ast(default_limit) do
    quote do
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)

      complexity(fn args, child_complexity ->
        Map.get(args, :limit, unquote(default_limit)) * child_complexity + 1
      end)
    end
  end

  defmacro page(type) do
    quote do
      object unquote(:"#{type}_page") do
        field(:prev_cursor, :string)
        field(:next_cursor, :string)
        field(:data, list_of(unquote(type)))
      end
    end
  end
end

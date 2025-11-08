defmodule AeMdwWeb.GraphQL.Schema.Helpers.Macros do
  defmacro pagination_args() do
    quote do
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)
    end
  end

  # TODO: this should invoke pagination_args/0 and add from_height and to_height
  defmacro pagination_args_with_scope() do
    quote do
      arg(:cursor, :string)
      arg(:limit, :integer)
      arg(:direction, :direction, default_value: :backward)
      arg(:from_height, :integer)
      arg(:to_height, :integer)
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

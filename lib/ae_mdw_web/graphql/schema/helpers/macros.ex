defmodule AeMdwWeb.GraphQL.Schema.Helpers.Macros do
  # TODO: this should be use page/2 macro
  defmacro page(type) do
    quote do
      object unquote(:"#{type}_page") do
        field(:prev_cursor, :string)
        field(:next_cursor, :string)
        field(:data, list_of(unquote(type)))
      end
    end
  end

  defmacro page(object, type) do
    quote do
      object unquote(object) do
        field(:prev_cursor, :string)
        field(:next_cursor, :string)
        field(:data, list_of(unquote(type)))
      end
    end
  end
end

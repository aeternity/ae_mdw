defmodule AeMdwWeb.GraphQL.Resolvers.Helpers do
  @min_page_limit 1
  @max_page_limit 100
  @default_page_limit 10

  def clamp_page_limit(limit) do
    cond do
      limit == nil -> @default_page_limit
      limit < @min_page_limit -> @min_page_limit
      limit > @max_page_limit -> @max_page_limit
      true -> limit
    end
  end

  # TODO: scoping does not always work as expected
  def make_scope(from_h, to_h) do
    cond do
      from_h && to_h -> {:gen, from_h..to_h}
      to_h && is_nil(from_h) -> nil
      from_h && is_nil(to_h) -> {:gen, from_h..from_h}
      true -> nil
    end
  end

  def cursor_val(nil), do: nil
  def cursor_val({val, _rev}), do: val
end

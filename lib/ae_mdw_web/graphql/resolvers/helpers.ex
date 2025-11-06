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

  # TODO: should nil be returned when only "to" is given?
  def make_scope(from, to) do
    cond do
      from && to -> {:gen, from..to}
      from && is_nil(to) -> {:gen, from..from}
      true -> nil
    end
  end

  def cursor_val(nil), do: nil
  def cursor_val({val, _rev}), do: val
end

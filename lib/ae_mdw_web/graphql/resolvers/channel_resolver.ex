defmodule AeMdwWeb.GraphQL.Resolvers.ChannelResolver do
  alias AeMdw.Channels
  alias AeMdw.Validate
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def channels(_p, args, %{context: %{state: state}}) do
    state_filter = Map.get(args, :state)
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query =
      case state_filter do
        nil -> %{}
        v when is_atom(v) -> %{"state" => Atom.to_string(v)}
        v -> %{"state" => to_string(v)}
      end

    case Channels.fetch_channels(state, pagination, scope, query, cursor) do
      {:ok, {prev, items, next}} ->
        {:ok,
         %{
           prev_cursor: Helpers.cursor_val(prev),
           next_cursor: Helpers.cursor_val(next),
           data: items |> Enum.map(&Helpers.normalize_map/1)
         }}

      {:error, err} ->
        {:error, ErrInput.message(err)}
    end
  end

  def channel(_p, %{id: id}, %{context: %{state: state}}) do
    with {:ok, channel_pk} <- Validate.id(id, [:channel]),
         {:ok, channel} <- Channels.fetch_channel(state, channel_pk, nil) do
      {:ok, channel |> Helpers.normalize_map()}
    else
      {:error, err} ->
        {:error, ErrInput.message(err)}
    end
  end

  def channel_updates(_p, %{id: id} = args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    case Channels.fetch_channel_updates(state, id, pagination, scope, cursor) do
      {:ok, {prev, items, next}} ->
        {:ok,
         %{
           prev_cursor: Helpers.cursor_val(prev),
           next_cursor: Helpers.cursor_val(next),
           data: items |> Enum.map(&Helpers.normalize_map/1)
         }}

      {:error, err} ->
        {:error, ErrInput.message(err)}
    end
  end
end

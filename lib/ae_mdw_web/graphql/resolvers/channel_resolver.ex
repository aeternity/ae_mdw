defmodule AeMdwWeb.GraphQL.Resolvers.ChannelResolver do
  alias AeMdw.Channels
  alias AeMdw.Validate
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

    Channels.fetch_channels(state, pagination, scope, query, cursor)
    |> Helpers.make_page()
  end

  def channel(_p, %{id: id}, %{context: %{state: state}}) do
    with {:ok, channel_pk} <- Validate.id(id, [:channel]) do
      Channels.fetch_channel(state, channel_pk, nil) |> Helpers.make_single()
    else
      {:error, err} ->
        {:error, Helpers.format_err(err)}
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

    Channels.fetch_channel_updates(state, id, pagination, scope, cursor)
    |> Helpers.make_page()
  end
end

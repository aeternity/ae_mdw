defmodule AeMdwWeb.GraphQL.Resolvers.ChannelResolver do
  alias AeMdw.Channels
  alias AeMdw.Validate
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def channels(_p, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query = Helpers.build_query(args, [:state])

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
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Channels.fetch_channel_updates(state, id, pagination, scope, cursor)
    |> Helpers.make_page()
  end
end

defmodule AeMdwWeb.GraphQL.Resolvers.ChannelResolver do
  alias AeMdw.Channels
  alias AeMdw.Validate
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  @spec channels(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def channels(_parent, args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    query = Helpers.build_query(args, [:state])

    Channels.fetch_channels(state, pagination, scope, query, cursor)
    |> Helpers.make_page()
  end

  @spec channel(any(), map(), Absinthe.Resolution.t()) :: {:ok, term()} | {:error, String.t()}
  def channel(_parent, %{id: id}, %{context: %{state: state}}) do
    case Validate.id(id, [:channel]) do
      {:ok, channel_pk} ->
        Channels.fetch_channel(state, channel_pk, nil) |> Helpers.make_single()

      {:error, err} ->
        {:error, Helpers.format_err(err)}
    end
  end

  @spec channel_updates(any(), map(), Absinthe.Resolution.t()) ::
          {:ok, term()} | {:error, String.t()}
  def channel_updates(_parent, %{id: id} = args, %{context: %{state: state}}) do
    %{pagination: pagination, cursor: cursor, scope: scope} =
      Helpers.pagination_args_with_scope(args)

    Channels.fetch_channel_updates(state, id, pagination, scope, cursor)
    |> Helpers.make_page()
  end
end

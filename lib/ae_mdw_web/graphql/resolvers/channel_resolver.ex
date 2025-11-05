defmodule AeMdwWeb.GraphQL.Resolvers.ChannelResolver do
  @moduledoc """
  Channel resolvers: list channels, fetch single channel (optionally at a given block), and channel updates.
  """
  alias AeMdw.{Channels, Validate}
  alias AeMdw.Db.State
  alias AeMdw.Error.Input, as: ErrInput

  @max_limit 100

  # -------------- Channels list --------------
  @spec channels(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def channels(_p, args, %{context: %{state: %State{} = state}}) do
    limit = clamp_limit(Map.get(args, :limit, 20))
    cursor = Map.get(args, :cursor)
    state_filter = Map.get(args, :state)
    from_h = Map.get(args, :from_height)
    to_h = Map.get(args, :to_height)

    range =
      cond do
        from_h && to_h -> {:gen, from_h..to_h}
        to_h && is_nil(from_h) -> {:gen, 0..to_h}
        from_h && is_nil(to_h) -> {:gen, from_h..from_h}
        true -> nil
      end

    query =
      case state_filter do
        nil -> %{}
        v when is_atom(v) -> %{"state" => Atom.to_string(v)}
        v -> %{"state" => to_string(v)}
      end

    pagination = {:backward, false, limit, not is_nil(cursor)}

    case Channels.fetch_channels(state, pagination, range, query, cursor) do
      {:ok, {prev, items, next}} ->
        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: items}}

      {:error, %ErrInput.Cursor{}} ->
        {:error, "invalid_cursor"}

      {:error, %ErrInput.Scope{}} ->
        {:error, "invalid_scope"}

      {:error, %ErrInput.Query{}} ->
        {:error, "invalid_filter"}

      {:error, _} ->
        {:error, "channels_error"}
    end
  end

  def channels(_, _args, _), do: {:error, "partial_state_unavailable"}

  # -------------- Single channel --------------
  @spec channel(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def channel(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    block_hash = Map.get(args, :block_hash)

    with {:ok, channel_pk} <- Validate.id(id, [:channel]),
         {:ok, type_block_hash} <- parse_optional_block_hash(block_hash),
         {:ok, channel} <- Channels.fetch_channel(state, channel_pk, type_block_hash) do
      {:ok, channel}
    else
      {:error, %ErrInput.Id{}} -> {:error, "invalid_channel_id"}
      {:error, %ErrInput.NotFound{}} -> {:error, "channel_not_found"}
      {:error, _} -> {:error, "channel_error"}
    end
  end

  def channel(_, _args, _), do: {:error, "partial_state_unavailable"}

  # -------------- Channel updates --------------
  @spec channel_updates(any, map(), Absinthe.Resolution.t()) ::
          {:ok, map()} | {:error, String.t()}
  def channel_updates(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    limit = clamp_limit(Map.get(args, :limit, 20))
    cursor = Map.get(args, :cursor)
    from_h = Map.get(args, :from_height)
    to_h = Map.get(args, :to_height)

    range =
      cond do
        from_h && to_h -> {:gen, from_h..to_h}
        to_h && is_nil(from_h) -> {:gen, 0..to_h}
        from_h && is_nil(to_h) -> {:gen, from_h..from_h}
        true -> nil
      end

    pagination = {:backward, false, limit, not is_nil(cursor)}

    case Channels.fetch_channel_updates(state, id, pagination, range, cursor) do
      {:ok, {prev, items, next}} ->
        {:ok, %{prev_cursor: cursor_val(prev), next_cursor: cursor_val(next), data: items}}

      {:error, %ErrInput.Cursor{}} ->
        {:error, "invalid_cursor"}

      {:error, %ErrInput.Scope{}} ->
        {:error, "invalid_scope"}

      {:error, %ErrInput.NotFound{}} ->
        {:error, "channel_not_found"}

      {:error, _} ->
        {:error, "channel_updates_error"}
    end
  end

  def channel_updates(_, _args, _), do: {:error, "partial_state_unavailable"}

  # -------------- Helpers --------------
  defp parse_optional_block_hash(nil), do: {:ok, nil}

  defp parse_optional_block_hash(block_hash) when is_binary(block_hash) do
    with {:ok, decoded} <- Validate.id(block_hash) do
      if String.starts_with?(block_hash, "kh") do
        {:ok, {:key, decoded}}
      else
        {:ok, {:micro, decoded}}
      end
    else
      _ -> {:error, ErrInput.Id.exception(value: block_hash)}
    end
  end

  defp cursor_val(nil), do: nil
  defp cursor_val({val, _rev}), do: val

  defp clamp_limit(l) when is_integer(l) and l > @max_limit, do: @max_limit
  defp clamp_limit(l) when is_integer(l) and l > 0, do: l
  defp clamp_limit(_), do: 20
end

defmodule AeMdwWeb.Websocket.SocketHandler do
  @moduledoc """
  Raw websocket server socket handler to broadcast blocks and transactions.
  """
  @behaviour Phoenix.Socket.Transport

  alias AeMdw.Validate
  alias AeMdwWeb.Websocket.ChainListener
  alias AeMdwWeb.Util

  require Ex2ms

  @subs_main :subs_main
  @subs_pids :subs_pids
  @subs_channel_targets :subs_channel_targets
  @subs_target_channels :subs_target_channels
  @known_prefixes ["ak_", "ct_", "ok_", "nm_", "cm_", "ch_"]
  @known_channels ["KeyBlocks", "MicroBlocks", "Transactions"]

  @impl Phoenix.Socket.Transport
  def child_spec(_opts) do
    # Won't spawn any additional process for the handler then returns a dummy task
    %{id: __MODULE__, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  @impl Phoenix.Socket.Transport
  def connect(state) do
    {:ok, state}
  end

  @impl Phoenix.Socket.Transport
  def init(state) do
    {:ok, Map.put(state, :channels, [])}
  end

  @spec channel_broadcast(binary(), binary()) :: :ok
  def channel_broadcast(channel, msg) do
    @subs_main
    |> :ets.match_object({{channel, :"$1"}, nil})
    |> Enum.each(fn {{^channel, pid}, nil} ->
      Process.send(pid, {channel, pid, msg}, [:noconnect])
    end)
  end

  @impl Phoenix.Socket.Transport
  def handle_info({channel, pid, msg}, state) do
    if :ets.member(@subs_main, {channel, pid}) do
      {:push, {:text, msg}, state}
    else
      {:ok, state}
    end
  end

  @impl Phoenix.Socket.Transport
  def terminate(_reason, _state) do
    :ok
  end

  @impl Phoenix.Socket.Transport
  def handle_in({text, _opts}, state) do
    text
    |> Jason.decode()
    |> case do
      {:ok, msg} ->
        handle_message(msg, state)

      {:error, %Jason.DecodeError{position: position}} ->
        reply_error("invalid json message", "at #{position}", state)
    end
  end

  defp handle_message(
         %{
           "op" => "Subscribe",
           "payload" => "Object",
           "target" => <<prefix_key::binary-size(3), rest::binary>> = target
         },
         %{channels: channels} = state
       )
       when prefix_key in @known_prefixes and byte_size(rest) >= 37 and byte_size(rest) <= 60 do
    if target in channels do
      reply_error("already subscribed to target", target, state)
    else
      case Validate.id(target) do
        {:ok, target_pk} ->
          ChainListener.register(self())
          :ets.insert(@subs_pids, {self(), nil})
          :ets.insert(@subs_main, {{target_pk, self()}, nil})
          :ets.insert(@subs_target_channels, {{target_pk, self()}, nil})
          :ets.insert(@subs_channel_targets, {{self(), target_pk}, nil})

          new_state = %{state | channels: [target | channels]}
          reply([target | channels], new_state)

        {:error, {_, k}} ->
          reply_error("invalid target", k, state)
      end
    end
  end

  defp handle_message(
         %{"op" => "Subscribe", "payload" => "Object", "target" => target},
         state
       ) do
    reply_error("invalid target", target, state)
  end

  defp handle_message(%{"op" => "Subscribe", "payload" => channel}, %{channels: channels} = state)
       when channel in @known_channels do
    if channel in channels do
      reply_error("already subscribed to", channel, state)
    else
      ChainListener.register(self())
      :ets.insert(@subs_main, {{channel, self()}, nil})

      new_state = %{state | channels: [channel | channels]}

      reply([channel | channels], new_state)
    end
  end

  defp handle_message(%{"op" => "Subscribe", "payload" => payload}, state)
       when payload == "Object" do
    reply_error("missing field", "target", state)
  end

  defp handle_message(%{"op" => "Subscribe", "payload" => payload}, state) do
    reply_error("invalid payload", payload, state)
  end

  defp handle_message(
         %{
           "op" => "Unsubscribe",
           "payload" => "Object",
           "target" => <<prefix_key::binary-size(3), rest::binary>> = target
         },
         %{channels: channels} = state
       )
       when prefix_key in @known_prefixes and byte_size(rest) >= 37 and byte_size(rest) <= 60 do
    if target in channels do
      case AeMdw.Validate.id(target) do
        {:ok, id} ->
          pid = self()
          :ets.delete(@subs_main, {target, self()})
          :ets.delete(@subs_target_channels, {id, pid})
          :ets.delete(@subs_channel_targets, {pid, id})

          spec =
            Ex2ms.fun do
              {{^pid, _}, _} -> true
            end

          if :ets.select_count(@subs_channel_targets, spec) == 0, do: :ets.delete(@subs_pids, pid)

          new_state = %{state | channels: List.delete(channels, target)}

          reply(new_state.channels, new_state)

        {:error, {_, k}} ->
          reply_error("invalid target", k, state)
      end
    else
      reply_error("no subscription for target", target, state)
    end
  end

  defp handle_message(
         %{"op" => "Unsubscribe", "payload" => "Object", "target" => target},
         state
       ) do
    reply_error("invalid target", target, state)
  end

  defp handle_message(
         %{"op" => "Unsubscribe", "payload" => channel},
         %{channels: channels} = state
       )
       when channel in @known_channels do
    if channel in channels do
      :ets.delete(@subs_main, {channel, self()})
      new_state = %{state | channels: List.delete(channels, channel)}

      reply(new_state.channels, new_state)
    else
      reply_error("no subscription for payload", channel, state)
    end
  end

  defp handle_message(%{"op" => "Unsubscribe", "payload" => payload}, state) do
    reply_error("invalid payload", payload, state)
  end

  defp handle_message(%{"op" => "Ping"}, state) do
    reply(%{"subscriptions" => state.channels, "payload" => "Pong"}, state)
  end

  defp handle_message(msg, state) do
    reply_error("invalid subscription", msg, state)
  end

  defp reply(msg, state) do
    {:reply, :ok, {:text, Jason.encode!(msg)}, state}
  end

  defp reply_error(topic, payload, state) do
    text = topic |> Util.concat(payload) |> Jason.encode!()
    {:reply, :ok, {:text, text}, state}
  end
end

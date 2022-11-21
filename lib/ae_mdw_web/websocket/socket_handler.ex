defmodule AeMdwWeb.Websocket.SocketHandler do
  @moduledoc """
  Raw websocket server socket handler to broadcast blocks and transactions.
  """
  @behaviour Phoenix.Socket.Transport

  alias AeMdwWeb.Websocket.Subscriptions
  alias AeMdwWeb.Util

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
    {:ok, state}
  end

  @spec send(pid(), binary()) :: :ok
  def send(pid, msg) do
    Process.send(pid, {:push, msg}, [:noconnect])
  end

  @impl Phoenix.Socket.Transport
  def handle_info({:push, msg}, state) do
    {:push, {:text, msg}, state}
  end

  def handle_info(_ignored_msg, state) do
    {:ok, state}
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
           "target" => target
         },
         state
       ) do
    case Subscriptions.subscribe(self(), target) do
      {:ok, channels} ->
        reply(channels, state)

      {:error, :already_subscribed} ->
        reply_error("already subscribed to target", target, state)

      {:error, :invalid_channel} ->
        reply_error("invalid target", target, state)
    end
  end

  defp handle_message(%{"op" => "Subscribe", "payload" => payload}, state)
       when payload == "Object" do
    reply_error("missing field", "target", state)
  end

  defp handle_message(%{"op" => "Subscribe", "payload" => channel}, state) do
    case Subscriptions.subscribe(self(), channel) do
      {:ok, channels} ->
        reply(channels, state)

      {:error, :already_subscribed} ->
        reply_error("already subscribed to", channel, state)

      {:error, :invalid_channel} ->
        reply_error("invalid payload", channel, state)

      {:error, :limit_reached} ->
        reply_error("invalid subscription", channel, state)
    end
  end

  defp handle_message(
         %{
           "op" => "Unsubscribe",
           "payload" => "Object",
           "target" => target
         },
         state
       ) do
    case Subscriptions.unsubscribe(self(), target) do
      {:ok, channels} ->
        reply(channels, state)

      {:error, :not_subscribed} ->
        reply_error("no subscription for target", target, state)

      {:error, :invalid_channel} ->
        reply_error("invalid target", target, state)
    end
  end

  defp handle_message(%{"op" => "Unsubscribe", "payload" => channel}, state) do
    case Subscriptions.unsubscribe(self(), channel) do
      {:ok, channels} ->
        reply(channels, state)

      {:error, :not_subscribed} ->
        reply_error("no subscription for payload", channel, state)

      {:error, :invalid_channel} ->
        reply_error("invalid payload", channel, state)
    end
  end

  defp handle_message(%{"op" => "Ping"}, state) do
    channels = Subscriptions.subscribed_channels(self())
    reply(%{"subscriptions" => channels, "payload" => "Pong"}, state)
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

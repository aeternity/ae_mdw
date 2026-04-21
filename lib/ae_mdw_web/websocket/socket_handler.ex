defmodule AeMdwWeb.Websocket.SocketHandler do
  @moduledoc """
  Raw websocket server socket handler to broadcast blocks and transactions.
  """
  @behaviour Phoenix.Socket.Transport

  alias AeMdwWeb.Websocket.Subscriptions
  alias AeMdwWeb.Util

  # Messages queued beyond this threshold indicate a slow/dead client; drop to protect broadcaster.
  @max_client_backlog Application.compile_env(:ae_mdw, __MODULE__, [])[:max_client_backlog] ||
                        2_000

  # Hard upper bound on the number of subscription entries returned in a single Ping response.
  # Clients monitoring large numbers of accounts already track their own state; Ping is a liveness
  # check. At 1000 x ~55 bytes/pubkey the JSON payload is ~60 KB, well within one WS frame.
  defp ping_limit,
    do: Application.get_env(:ae_mdw, __MODULE__, [])[:max_ping_limit] || 1_000

  @impl Phoenix.Socket.Transport
  def child_spec(_opts) do
    # Won't spawn any additional process for the handler then returns a dummy task
    %{id: __MODULE__, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  @impl Phoenix.Socket.Transport
  def connect(%{connect_info: %{version: version} = connect_info})
      when version in [:v1, :v2, :v3] do
    ip =
      case connect_info do
        %{peer_data: %{address: addr}} -> addr |> :inet.ntoa() |> to_string()
        _other -> "unknown"
      end

    {:ok, %{version: version, peer_ip: ip}}
  end

  @impl Phoenix.Socket.Transport
  def init(%{peer_ip: peer_ip} = state) do
    case Subscriptions.register_connection(self(), peer_ip) do
      :ok ->
        {:ok, state}

      {:error, reason} ->
        Process.send(self(), {:close_connection, reason}, [])
        {:ok, state}
    end
  end

  @spec send(pid(), binary()) :: :ok
  def send(pid, msg) do
    case Process.info(pid, :message_queue_len) do
      {:message_queue_len, len} when len < @max_client_backlog ->
        Process.send(pid, {:push, msg}, [:noconnect])

      nil ->
        # Process already dead
        :ok

      _above_limit ->
        # Slow or dead client — drop message to protect the broadcaster
        :ok
    end
  end

  @impl Phoenix.Socket.Transport
  def handle_info({:push, msg}, state) do
    {:push, {:text, msg}, state}
  end

  def handle_info({:close_connection, reason}, state) do
    require Logger
    Logger.warning("[ws] connection rejected: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  def handle_info(_ignored_msg, state) do
    {:ok, state}
  end

  @impl Phoenix.Socket.Transport
  def terminate(_reason, _state) do
    Subscriptions.deregister_connection(self())
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
         } = sub,
         %{version: version} = state
       ) do
    with {:ok, source} <- get_source(sub),
         {:ok, channels} <- Subscriptions.subscribe(self(), source, version, target) do
      reply(channels, state)
    else
      {:error, :already_subscribed} ->
        reply_error("already subscribed to target", target, state)

      {:error, :invalid_channel} ->
        reply_error("invalid target", target, state)

      {:error, :invalid_source, source} ->
        reply_error("invalid source", source, state)

      {:error, :limit_reached} ->
        reply_error("too many subscriptions! discarding", target, state)
    end
  end

  defp handle_message(%{"op" => "Subscribe", "payload" => payload}, state)
       when payload == "Object" do
    reply_error("missing field", "target", state)
  end

  defp handle_message(
         %{"op" => "Subscribe", "payload" => channel} = sub,
         %{version: version} = state
       ) do
    with {:ok, source} <- get_source(sub),
         {:ok, channels} <- Subscriptions.subscribe(self(), source, version, channel) do
      reply(channels, state)
    else
      {:error, :already_subscribed} ->
        reply_error("already subscribed to", channel, state)

      {:error, :invalid_channel} ->
        reply_error("invalid payload", channel, state)

      {:error, :invalid_source, source} ->
        reply_error("invalid source", source, state)

      {:error, :limit_reached} ->
        reply_error("too many subscriptions! discarding", channel, state)
    end
  end

  defp handle_message(
         %{
           "op" => "Unsubscribe",
           "payload" => "Object",
           "target" => target
         } = sub,
         %{version: version} = state
       ) do
    with {:ok, source} <- get_source(sub),
         {:ok, channels} <- Subscriptions.unsubscribe(self(), source, version, target) do
      reply(channels, state)
    else
      {:error, :not_subscribed} ->
        reply_error("no subscription for target", target, state)

      {:error, :invalid_channel} ->
        reply_error("invalid target", target, state)

      {:error, :invalid_source, source} ->
        reply_error("invalid source", source, state)
    end
  end

  defp handle_message(
         %{"op" => "Unsubscribe", "payload" => channel} = sub,
         %{version: version} = state
       ) do
    with {:ok, source} <- get_source(sub),
         {:ok, channels} <- Subscriptions.unsubscribe(self(), source, version, channel) do
      reply(channels, state)
    else
      {:error, :not_subscribed} ->
        reply_error("no subscription for payload", channel, state)

      {:error, :invalid_channel} ->
        reply_error("invalid payload", channel, state)

      {:error, :invalid_source, source} ->
        reply_error("invalid source", source, state)
    end
  end

  defp handle_message(%{"op" => "Ping"}, state) do
    limit = ping_limit()
    {channels, total} = Subscriptions.subscribed_channels_sample(self(), limit)

    response =
      %{"subscriptions" => channels, "count" => total, "payload" => "Pong"}
      |> then(fn r -> if total > limit, do: Map.put(r, "has_more", true), else: r end)

    reply(response, state)
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

  defp get_source(%{"source" => source}) when source in ["mdw", "node"],
    do: {:ok, String.to_existing_atom(source)}

  defp get_source(%{"source" => source}), do: {:error, :invalid_source, source}
  defp get_source(_sub), do: {:ok, :mdw}
end

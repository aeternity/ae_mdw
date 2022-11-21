defmodule AeMdwWeb.Websocket.Subscriptions do
  @moduledoc """
  Manages websocket subscriptions in order to limit its amount per subscriber and list subscribers of a certain channel.

  Subscriber is a pid and a channel is:
  a) A "KeyBlocks" or "MicroBlocks" or "Transactions" String
  b) The target for an "Object" subscription. The channel key is the 256 bit target object id like pubkey, name hash, channel id, etc.
  """
  use GenServer

  alias AeMdw.Validate

  require Ex2ms

  @type channel :: <<_::256>> | String.t()
  @subs_pids :subs_pids
  @subs_channel_pid :subs_channel_pid
  @subs_pid_channel :subs_pid_channel
  @eot :"$end_of_table"

  @known_channels ["KeyBlocks", "MicroBlocks", "Transactions"]

  @spec init_tables() :: :ok
  def init_tables() do
    all_tables = :ets.all()

    if nil == Enum.find(all_tables, &(&1 == @subs_pids)) do
      :subs_pids = :ets.new(@subs_pids, [:public, :set, :named_table])
      :subs_channel_pid = :ets.new(@subs_channel_pid, [:public, :duplicate_bag, :named_table])
      :subs_pid_channel = :ets.new(@subs_pid_channel, [:public, :duplicate_bag, :named_table])
    end

    :ok
  end

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_arg), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl GenServer
  def init(:ok) do
    @subs_pids
    |> :ets.match({:"$1", :_})
    |> Enum.each(fn [pid] ->
      ref = Process.monitor(pid)
      :ets.insert(@subs_pids, {pid, ref})
    end)

    {:ok, :no_state}
  end

  @spec subscribe(pid(), channel()) ::
          {:ok, [channel()]} | {:error, :invalid_channel | :already_subscribed}
  def subscribe(pid, channel) do
    with {:ok, channel_key} <- validate_subscribe(pid, channel) do
      maybe_monitor(pid)
      :ets.insert(@subs_pid_channel, {pid, channel})
      :ets.insert(@subs_channel_pid, {channel_key, pid})

      {:ok, subscribed_channels(pid)}
    end
  end

  @spec unsubscribe(pid(), channel()) ::
          {:ok, [channel()]} | {:error, :invalid_channel | :not_subscribed}
  def unsubscribe(pid, channel) do
    with {:ok, channel_key} <- validate_unsubscribe(pid, channel) do
      :ets.delete_object(@subs_channel_pid, {channel_key, pid})
      :ets.delete_object(@subs_pid_channel, {pid, channel})

      {:ok, subscribed_channels(pid)}
    end
  end

  @spec subscribers(channel()) :: [pid()]
  def subscribers(channel) do
    @subs_channel_pid
    |> :ets.match({channel, :"$1"})
    |> List.flatten()
  end

  @spec subscribed_channels(pid()) :: [channel()]
  def subscribed_channels(pid) do
    @subs_pid_channel
    |> :ets.match({pid, :"$1"})
    |> List.flatten()
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, _type, pid, _info}, state) do
    # last connection down
    if :ets.info(@subs_pids, :size) <= 1 do
      Enum.each(
        [@subs_pids, @subs_channel_pid, @subs_pid_channel],
        &:ets.delete_all_objects/1
      )
    else
      unsubscribe_all(pid)
    end

    maybe_demonitor(pid)

    {:noreply, state}
  end

  def handle_info(_other_message, state), do: {:noreply, state}

  @impl GenServer
  def handle_cast({:monitor, pid}, state) do
    ref = Process.monitor(pid)
    :ets.insert(@subs_pids, {pid, ref})

    {:noreply, state}
  end

  defp maybe_monitor(pid) do
    if not :ets.member(@subs_pids, pid) do
      GenServer.cast(__MODULE__, {:monitor, pid})
    end
  end

  defp maybe_demonitor(pid) do
    with [{^pid, ref}] <- :ets.lookup(@subs_pids, pid) do
      Process.demonitor(ref, [:flush])
      :ets.delete(@subs_pids, pid)
    end

    :ok
  end

  defp unsubscribe_all(pid) do
    @subs_pid_channel
    |> :ets.match_object({pid, :"$1"})
    |> Enum.each(fn {^pid, channel} ->
      :ets.delete_object(@subs_pid_channel, {pid, channel})
      {:ok, channel_key} = channel_key(channel)
      :ets.delete_object(@subs_channel_pid, {channel_key, pid})
    end)
  end

  defp validate_subscribe(pid, channel) do
    with {:ok, channel_key} <- channel_key(channel),
         {:exists, false} <- {:exists, exists?(pid, channel)} do
      {:ok, channel_key}
    else
      {:error, _reason} -> {:error, :invalid_channel}
      {:exists, true} -> {:error, :already_subscribed}
    end
  end

  defp validate_unsubscribe(pid, channel) do
    with {:ok, channel_key} <- channel_key(channel),
         true <- exists?(pid, channel) do
      {:ok, channel_key}
    else
      {:error, _reason} -> {:error, :invalid_channel}
      false -> {:error, :not_subscribed}
    end
  end

  defp channel_key(channel) when channel in @known_channels, do: {:ok, channel}
  defp channel_key(channel), do: Validate.id(channel)

  defp exists?(pid, channel) do
    case :ets.match_object(@subs_pid_channel, {pid, channel}, 1) do
      @eot -> false
      {_match, _cont} -> true
    end
  end
end

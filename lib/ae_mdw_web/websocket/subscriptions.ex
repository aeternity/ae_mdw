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
  @limit_per_pid Application.compile_env(:ae_mdw, [__MODULE__, :max_subs_per_conn])
  @eot :"$end_of_table"
  @counter_pos 3

  @known_channels ["KeyBlocks", "MicroBlocks", "Transactions"]

  @type source :: :node | :mdw
  @type version :: :v1 | :v2

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
    |> :ets.match({:"$1", :_, :"$2"})
    |> Enum.each(fn [pid, count] ->
      ref = Process.monitor(pid)
      :ets.insert(@subs_pids, {pid, ref, count})
    end)

    {:ok, :no_state}
  end

  @spec subscribe(pid(), source(), version(), channel()) ::
          {:ok, [channel()]} | {:error, :invalid_channel | :already_subscribed | :limit_reached}
  def subscribe(pid, source, version, channel) do
    with {:ok, channel_key} <- validate_subscribe(pid, source, version, channel) do
      maybe_monitor(pid)
      :ets.insert(@subs_pid_channel, {pid, channel_key, channel})
      :ets.insert(@subs_channel_pid, {channel_key, pid})

      {:ok, subscribed_channels(pid)}
    end
  end

  @spec unsubscribe(pid(), source(), version(), channel()) ::
          {:ok, [channel()]} | {:error, :invalid_channel | :not_subscribed}
  def unsubscribe(pid, source, version, channel) do
    with {:ok, channel_key} <- validate_unsubscribe(pid, source, version, channel) do
      :ets.update_counter(@subs_pids, pid, {@counter_pos, -1}, {pid, nil, 0})
      :ets.delete_object(@subs_channel_pid, {channel_key, pid})
      :ets.match_delete(@subs_pid_channel, {pid, channel_key, :_})

      {:ok, subscribed_channels(pid)}
    end
  end

  @spec has_subscribers?(source(), version(), channel) :: boolean()
  def has_subscribers?(source, version, channel) do
    {:ok, channel_key} = channel_key(source, version, channel)

    case :ets.match(@subs_channel_pid, {channel_key, :"$1"}, 1) do
      {_some, _continuation} -> true
      @eot -> false
    end
  end

  @spec has_object_subscribers?(source(), version()) :: boolean()
  def has_object_subscribers?(source, version) do
    object_id_spec =
      Ex2ms.fun do
        {{^source, ^version, channel}, pid}
        when channel != "KeyBlocks" and channel != "MicroBlocks" and channel != "Transactions" ->
          pid
      end

    case :ets.select(@subs_channel_pid, object_id_spec, 1) do
      {_some, _continuation} -> true
      @eot -> false
    end
  end

  @spec subscribers(source(), version(), channel()) :: [pid()]
  def subscribers(source, version, channel) do
    {:ok, channel_key} = channel_key(source, version, channel)

    @subs_channel_pid
    |> :ets.match({channel_key, :"$1"})
    |> List.flatten()
  end

  @spec subscribed_channels(pid()) :: [channel()]
  def subscribed_channels(pid) do
    @subs_pid_channel
    |> :ets.match({pid, :_, :"$1"})
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
    :ets.insert(@subs_pids, {pid, ref, 1})

    {:noreply, state}
  end

  defp maybe_monitor(pid) do
    if :ets.member(@subs_pids, pid) do
      :ets.update_counter(@subs_pids, pid, {@counter_pos, 1})
      :ok
    else
      GenServer.cast(__MODULE__, {:monitor, pid})
    end
  end

  defp maybe_demonitor(pid) do
    with [{^pid, ref, _count}] <- :ets.lookup(@subs_pids, pid) do
      Process.demonitor(ref, [:flush])
      :ets.delete(@subs_pids, pid)
    end

    :ok
  end

  defp unsubscribe_all(pid) do
    @subs_pid_channel
    |> :ets.match_object({pid, :"$1"})
    |> Enum.each(fn {^pid, channel_key, channel} ->
      :ets.delete_object(@subs_pid_channel, {pid, channel_key, channel})
      :ets.delete_object(@subs_channel_pid, {channel_key, pid})
    end)
  end

  defp validate_subscribe(pid, source, version, channel) do
    with {:ok, channel_key} <- channel_key(source, version, channel),
         false <- exists?(pid, channel_key),
         count when count < @limit_per_pid <- subscriptions_count(pid) do
      {:ok, channel_key}
    else
      {:error, _reason} -> {:error, :invalid_channel}
      true -> {:error, :already_subscribed}
      _above_limit -> {:error, :limit_reached}
    end
  end

  defp validate_unsubscribe(pid, source, version, channel) do
    with {:ok, channel_key} <- channel_key(source, version, channel),
         true <- exists?(pid, channel_key) do
      {:ok, channel_key}
    else
      {:error, _reason} -> {:error, :invalid_channel}
      false -> {:error, :not_subscribed}
    end
  end

  defp channel_key(source, version, channel) when channel in @known_channels,
    do: {:ok, {source, version, channel}}

  defp channel_key(source, version, channel) do
    with {:ok, pubkey} <- Validate.id(channel) do
      {:ok, {source, version, pubkey}}
    end
  end

  defp exists?(pid, channel_key) do
    case :ets.match(@subs_pid_channel, {pid, channel_key, :"$1"}, 1) do
      {[[_channel]], _cont} -> true
      @eot -> false
    end
  end

  defp subscriptions_count(pid) do
    case :ets.lookup(@subs_pids, pid) do
      [{_pid, _ref, count}] -> count
      [] -> 0
    end
  end
end

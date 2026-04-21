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
  @ws_connections :ws_connections
  @ws_ip_counts :ws_ip_counts
  @eot :"$end_of_table"
  @counter_pos 3

  @known_channels ["KeyBlocks", "MicroBlocks", "Transactions"]

  @type source :: :node | :mdw
  @type version :: :v1 | :v2 | :v3

  @spec init_tables() :: :ok
  def init_tables() do
    all_tables = :ets.all()

    if nil == Enum.find(all_tables, &(&1 == @subs_pids)) do
      :subs_pids = :ets.new(@subs_pids, [:public, :set, :named_table])
      :subs_channel_pid = :ets.new(@subs_channel_pid, [:public, :duplicate_bag, :named_table])
      :subs_pid_channel = :ets.new(@subs_pid_channel, [:public, :duplicate_bag, :named_table])
      :ws_connections = :ets.new(@ws_connections, [:public, :set, :named_table])
      :ws_ip_counts = :ets.new(@ws_ip_counts, [:public, :set, :named_table])
    end

    :ok
  end

  @spec register_connection(pid(), String.t()) ::
          :ok | {:error, :too_many_connections | :too_many_connections_from_ip}
  def register_connection(pid, ip),
    do: GenServer.call(__MODULE__, {:register_connection, pid, ip})

  @spec deregister_connection(pid()) :: :ok
  def deregister_connection(pid), do: GenServer.cast(__MODULE__, {:deregister_connection, pid})

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

    @ws_connections
    |> :ets.tab2list()
    |> Enum.each(fn {pid, _ref, ip} ->
      ref = Process.monitor(pid)
      :ets.insert(@ws_connections, {pid, ref, ip})
    end)

    {:ok, :no_state}
  end

  @impl GenServer
  def handle_call({:register_connection, pid, ip}, _from, state) do
    total = :ets.info(@ws_connections, :size)

    ip_count =
      case :ets.lookup(@ws_ip_counts, ip) do
        [{^ip, count}] -> count
        [] -> 0
      end

    cond do
      total >= limit_total_connections() ->
        {:reply, {:error, :too_many_connections}, state}

      ip_count >= limit_per_ip_connections() ->
        {:reply, {:error, :too_many_connections_from_ip}, state}

      true ->
        ref = Process.monitor(pid)
        :ets.insert(@ws_connections, {pid, ref, ip})
        :ets.update_counter(@ws_ip_counts, ip, {2, 1}, {ip, 0})
        {:reply, :ok, state}
    end
  end

  @impl GenServer
  def handle_cast({:deregister_connection, pid}, state) do
    cleanup_connection(pid)
    {:noreply, state}
  end

  def handle_cast({:monitor, pid}, state) do
    ref = Process.monitor(pid)
    :ets.insert(@subs_pids, {pid, ref, 1})

    {:noreply, state}
  end

  @spec subscribe(pid(), source(), version(), channel()) ::
          {:ok, [channel()]} | {:error, :invalid_channel | :already_subscribed | :limit_reached}
  def subscribe(pid, source, version, channel) do
    with {:ok, channel_key} <- validate_subscribe(pid, source, version, channel) do
      maybe_monitor(pid)
      :ets.insert(@subs_pid_channel, {pid, channel_key, channel})
      :ets.insert(@subs_channel_pid, {channel_key, pid})

      {:ok, reply_channels(pid, channel)}
    end
  end

  @spec unsubscribe(pid(), source(), version(), channel()) ::
          {:ok, [channel()]} | {:error, :invalid_channel | :not_subscribed}
  def unsubscribe(pid, source, version, channel) do
    with {:ok, channel_key} <- validate_unsubscribe(pid, source, version, channel) do
      :ets.update_counter(@subs_pids, pid, {@counter_pos, -1}, {pid, nil, 0})
      :ets.delete_object(@subs_channel_pid, {channel_key, pid})
      :ets.match_delete(@subs_pid_channel, {pid, channel_key, :_})

      {:ok, reply_channels(pid, channel)}
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

  @spec subscribed_channels_sample(pid(), pos_integer()) :: {[channel()], non_neg_integer()}
  def subscribed_channels_sample(pid, limit) do
    total = subscriptions_count(pid)

    channels =
      case :ets.match(@subs_pid_channel, {pid, :_, :"$1"}, limit) do
        {rows, _cont} -> List.flatten(rows)
        @eot -> []
      end

    {channels, total}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, _type, pid, _info}, state) do
    # Subscription cleanup
    if :ets.member(@subs_pids, pid) do
      unsubscribe_all(pid)
      maybe_demonitor(pid)
    end

    # Connection cleanup (idempotent — :ets.take/2 returns [] if already gone)
    cleanup_connection(pid)

    {:noreply, state}
  end

  def handle_info(_other_message, state), do: {:noreply, state}

  defp maybe_monitor(pid) do
    if :ets.member(@subs_pids, pid) do
      :ets.update_counter(@subs_pids, pid, {@counter_pos, 1})
      :ok
    else
      GenServer.cast(__MODULE__, {:monitor, pid})
    end
  end

  defp maybe_demonitor(pid) do
    _lookup_return =
      with [{^pid, ref, _count}] <- :ets.lookup(@subs_pids, pid) do
        Process.demonitor(ref, [:flush])
        :ets.delete(@subs_pids, pid)
      end

    :ok
  end

  defp unsubscribe_all(pid) do
    channel_keys =
      @subs_pid_channel
      |> :ets.match({pid, :"$1", :_})
      |> List.flatten()

    :ets.match_delete(@subs_pid_channel, {pid, :_, :_})
    Enum.each(channel_keys, &:ets.delete_object(@subs_channel_pid, {&1, pid}))
  end

  defp validate_subscribe(pid, source, version, channel) do
    per_pid_limit = limit_per_pid()
    total_subs_limit = limit_total_subs()

    with {:ok, channel_key} <- channel_key(source, version, channel),
         false <- exists?(pid, channel_key),
         count when count < per_pid_limit <- subscriptions_count(pid),
         total_rows when total_rows < total_subs_limit <- :ets.info(@subs_pid_channel, :size) do
      {:ok, channel_key}
    else
      {:error, _reason} -> {:error, :invalid_channel}
      true -> {:error, :already_subscribed}
      _above_limit -> {:error, :limit_reached}
    end
  end

  defp reply_channels(pid, channel) do
    if Application.get_env(:ae_mdw, __MODULE__)[:subs_full_list_reply] do
      subscribed_channels(pid)
    else
      [channel]
    end
  end

  defp limit_per_pid do
    Application.get_env(:ae_mdw, __MODULE__)[:max_subs_per_conn]
  end

  defp limit_total_connections do
    Application.get_env(:ae_mdw, __MODULE__)[:max_total_connections] || 1_000
  end

  defp limit_per_ip_connections do
    Application.get_env(:ae_mdw, __MODULE__)[:max_connections_per_ip] || 10
  end

  defp limit_total_subs do
    Application.get_env(:ae_mdw, __MODULE__)[:max_total_subs] || 500_000
  end

  defp cleanup_connection(pid) do
    case :ets.take(@ws_connections, pid) do
      [{^pid, ref, ip}] ->
        Process.demonitor(ref, [:flush])
        new_count = :ets.update_counter(@ws_ip_counts, ip, {2, -1}, {ip, 0})
        if new_count <= 0, do: :ets.delete(@ws_ip_counts, ip)

      [] ->
        :ok
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

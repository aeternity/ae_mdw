defmodule AeMdw.Sync.Watcher do
  @moduledoc """
  Notifies by email when sync finishes with a reason other than `:normal`.
  """
  use GenServer

  import AeMdw.Util

  defstruct [:operators, :sync_mon_ref]

  @spec start_link([]) :: GenServer.on_start()
  def start_link([]),
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @impl GenServer
  def init([]) do
    operators = Application.fetch_env!(:ae_mdw, :operators)
    ref? = map_some(Process.whereis(AeMdw.Db.Sync), &Process.monitor/1)
    {:ok, %__MODULE__{operators: operators, sync_mon_ref: ref?}}
  end

  @spec notify_sync(pid()) :: :ok
  def notify_sync(sync_pid),
    do: GenServer.cast(__MODULE__, {:sync_process, sync_pid})

  @impl GenServer
  def handle_cast({:sync_process, pid}, %__MODULE__{} = s),
    do: {:noreply, %{s | sync_mon_ref: Process.monitor(pid)}}

  @impl GenServer
  def handle_info({:DOWN, ref, :process, _, :normal}, %__MODULE__{sync_mon_ref: ref} = s),
    do: %{s | sync_mon_ref: nil}

  @impl GenServer
  def handle_info({:DOWN, ref, :process, _, reason}, %__MODULE__{sync_mon_ref: ref} = s) do
    notify_operators(s.operators, reason)
    {:noreply, %{s | sync_mon_ref: nil}}
  end

  #
  # Private functions
  #
  defp notify_operators(emails, reason) do
    attachment = Temp.path!()

    try do
      File.write!(attachment, "#{inspect(reason, pretty: true, limit: :infinity)}")
      subject = "syncing crashed on #{host_ip_address()}"
      send_mail(emails, subject, attachment)
    after
      File.rm(attachment)
    end
  end

  defp send_mail(emails, subject, attachment) do
    emails = Enum.join(emails, " ")
    cmd = "mail -s \"#{subject}\" -A #{attachment} #{emails}"

    try do
      System.cmd(cmd, [])
    rescue
      # in case `mail` command is not present (exception is logged)
      _error -> nil
    end
  end

  defp host_ip_address() do
    [{ip_addr, _, _} | _] =
      Enum.reject(ok!(:inet.getif()), fn
        {{127, _, _, _}, _, _} -> true
        _other_ip -> false
      end)

    "#{:inet.ntoa(ip_addr)}"
  end
end

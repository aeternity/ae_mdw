defmodule AeMdw.Sync.Watcher do
  # credo:disable-for-this-file
  use GenServer

  import AeMdw.Util

  defstruct [:operators, :sync_mon_ref]

  ################################################################################

  def start_link(_),
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init([]) do
    operators = Application.fetch_env!(:ae_mdw, :operators)
    ref? = map_some(Process.whereis(AeMdw.Db.Sync), &Process.monitor/1)
    {:ok, %__MODULE__{operators: operators, sync_mon_ref: ref?}}
  end

  def handle_cast({:sync_process, pid}, %__MODULE__{} = s),
    do: {:noreply, %{s | sync_mon_ref: Process.monitor(pid)}}

  def handle_info({:DOWN, ref, :process, _, :normal}, %__MODULE__{sync_mon_ref: ref} = s),
    do: %{s | sync_mon_ref: nil}

  def handle_info({:DOWN, ref, :process, _, reason}, %__MODULE__{sync_mon_ref: ref} = s) do
    notify_operators(s.operators, reason)
    {:noreply, %{s | sync_mon_ref: nil}}
  end

  def notify_operators(emails, reason) do
    attachment = Temp.path!()

    try do
      File.write!(attachment, "#{inspect(reason, pretty: true, limit: :infinity)}")
      subject = "syncing crashed on #{host_ip_address()}"
      send_mail(emails, subject, attachment)
    after
      File.rm(attachment)
    end
  end

  def send_mail(emails, subject, attachment) do
    emails = Enum.join(emails, " ")
    cmd = "mail -s \"#{subject}\" -A #{attachment} #{emails}"

    try do
      System.cmd(cmd, [])
    rescue
      # in case `mail` command is not present
      _ -> nil
    end
  end

  def host_ip_address() do
    [{ip_addr, _, _} | _] =
      Enum.reject(ok!(:inet.getif()), fn
        {{127, _, _, _}, _, _} -> true
        _ -> false
      end)

    "#{:inet.ntoa(ip_addr)}"
  end
end

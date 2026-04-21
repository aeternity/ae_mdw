defmodule Support.WsUtil do
  # credo:disable-for-this-file

  def unsubscribe_all(version) when is_atom(version) do
    :ets.match_delete(:subs_channel_pid, {{:_, version, :_}, :_})
  end

  def unsubscribe_all(pids) when is_list(pids) do
    Enum.each(pids, &do_unsubscribe_all/1)
  end

  defp do_unsubscribe_all(pid) do
    :ets.delete(:subs_pids, pid)

    channel_keys =
      :subs_pid_channel
      |> :ets.match({pid, :"$1", :_})
      |> List.flatten()

    :ets.match_delete(:subs_pid_channel, {pid, :_, :_})
    Enum.each(channel_keys, &:ets.delete_object(:subs_channel_pid, {&1, pid}))
  end
end

defmodule Support.WsUtil do
  # credo:disable-for-this-file

  def unsubscribe_all(pids) when is_list(pids) do
    Enum.each(pids, &do_unsubscribe_all/1)
  end

  defp do_unsubscribe_all(pid) do
    :ets.delete(:subs_pids, pid)

    :subs_pid_channel
    |> :ets.match_object({pid, :"$1"})
    |> Enum.each(fn {^pid, channel_key} ->
      :ets.delete_object(:subs_pid_channel, {pid, channel_key})
      :ets.delete_object(:subs_channel_pid, {channel_key, pid})
    end)
  end
end

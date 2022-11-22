defmodule Support.WsUtil do
  # credo:disable-for-this-file

  alias AeMdw.Validate

  def unsubscribe_all(pids) when is_list(pids) do
    Enum.each(pids, &do_unsubscribe_all/1)
  end

  defp do_unsubscribe_all(pid) do
    :ets.delete(:subs_pids, pid)

    :subs_pid_channel
    |> :ets.match_object({pid, :"$1"})
    |> Enum.each(fn {^pid, channel} ->
      :ets.delete_object(:subs_pid_channel, {pid, channel})

      channel_key =
        if String.starts_with?(channel, "ak"), do: Validate.id!(channel), else: channel

      :ets.delete_object(:subs_channel_pid, {channel_key, pid})
    end)
  end
end

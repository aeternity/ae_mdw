defmodule AeMdw.Util.Semaphore do
  @moduledoc """
  Simple BEAM processes semaphores implementation.
  """

  @type limit() :: non_neg_integer()

  @opaque t() :: pid()

  @spec new(limit()) :: t()
  def new(i), do: spawn_link(fn -> semaphore(i) end)

  @spec signal(t()) :: :ok
  def signal(sem), do: Process.send(sem, :signal, [])

  @spec wait(t()) :: :ok
  def wait(sem) do
    Process.send(sem, {:wait, self()}, [])

    receive do
      :ok -> :ok
    end
  end

  @spec stop(t()) :: :ok
  def stop(sem) do
    Process.send(sem, :stop, [])
  end

  defp semaphore(0) do
    receive do
      :signal -> semaphore(1)
      :stop -> :ok
    end
  end

  defp semaphore(n) do
    receive do
      :signal ->
        semaphore(n + 1)

      {:wait, pid} ->
        Process.send(pid, :ok, [])

        semaphore(n - 1)

      :stop ->
        :ok
    end
  end
end

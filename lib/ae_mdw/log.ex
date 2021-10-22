defmodule AeMdw.Log do
  require Logger

  @spec info(String.t()) :: :ok
  def info(msg),
    do: Logger.info(msg, sync: true)

  @spec warn(String.t()) :: :ok
  def warn(msg),
    do: Logger.warn(msg, sync: true)

  @spec error(String.t()) :: :ok
  def error(msg),
    do: Logger.error(msg, sync: true)
end

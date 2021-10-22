defmodule AeMdw.Log do
  require Logger

  def info(msg),
    do: Logger.info(msg, sync: true)

  def warn(msg),
    do: Logger.warn(msg, sync: true)

  def error(msg),
    do: Logger.error(msg, sync: true)
end

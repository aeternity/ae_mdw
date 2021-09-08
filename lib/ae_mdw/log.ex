defmodule AeMdw.Log do
  require Logger

  def info(msg),
    do: Logger.info(msg, sync: true)

  def warn(msg),
    do: Logger.warn(msg, sync: true)
end

defmodule AeMdw.Log do

  require Logger

  def info(msg),
    do: Logger.info(msg, sync: true)

end

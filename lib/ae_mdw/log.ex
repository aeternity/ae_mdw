defmodule AeMdw.Log do
  @moduledoc """
  Simple Logger wrapper to force sync.
  """
  require Logger

  @typep exception() :: %{:__exception__ => true, :__struct__ => atom(), atom() => any()}

  @spec info(String.t() | map()) :: :ok
  def info(msg),
    do: Logger.info(msg)

  @spec warn(String.t()) :: :ok
  def warn(msg),
    do: Logger.warn(msg)

  @spec error(String.t() | exception()) :: :ok
  def error(msg) when is_binary(msg),
    do: Logger.error(msg)

  def error(msg),
    do: Logger.error(inspect(msg))
end

defmodule Support.TestMnesiaSandbox do
  @moduledoc """
  Executes an Mnesia transaction to be rolledback.
  """

  @spec mnesia_sandbox(fun()) :: :pass | no_return()
  def mnesia_sandbox(func) do
    # shall always terminate either by an assertion error or by a rollback
    case :mnesia.transaction(func) do
      {:aborted, {%ExUnit.AssertionError{} = assertion_error, _stacktrace}} ->
        raise assertion_error

      {:aborted, :rollback} ->
        :pass
    end
  end
end

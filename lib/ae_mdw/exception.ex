defmodule AeMdw.Exception do
  @moduledoc """
  Base module for defining custom exceptions.
  """

  defmacro defexception!(name) do
    quote do
      defmodule unquote(name) do
        defexception [:value]

        @impl true
        def exception(value: value),
          do: %AeMdw.Error.Input{
            reason: __MODULE__,
            message: AeMdw.Error.to_string(__MODULE__, value)
          }

        @impl true
        def message(%AeMdw.Error.Input{message: m}), do: m
      end
    end
  end
end

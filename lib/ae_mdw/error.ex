defmodule AeMdw.Error do
  defmodule Input do
    defexception [:message]

    defmodule Id do
      def exception(value: value),
        do: %AeMdw.Error.Input{message: "invalid id: #{inspect(value)}"}
    end

    defmodule NonnegInt do
      def exception(value: value),
        do: %AeMdw.Error.Input{message: "invalid non-negative integer: #{inspect(value)}"}
    end

    defmodule TxField do
      def exception(value: value),
        do: %AeMdw.Error.Input{message: "invalid transaction field: #{inspect(value)}"}
    end

    defmodule TxType do
      def exception(value: value),
        do: %AeMdw.Error.Input{message: "invalid transaction type: #{inspect(value)}"}
    end

    defmodule TxGroup do
      def exception(value: value),
        do: %AeMdw.Error.Input{message: "invalid transaction group: #{inspect(value)}"}
    end

    defmodule Scope do
      def exception(value: value),
        do: %AeMdw.Error.Input{message: "invalid scope: #{inspect(value)}"}
    end

    defmodule Query do
      def exception(value: value),
        do: %AeMdw.Error.Input{message: "invalid query: #{inspect(value)}"}
    end
  end
end

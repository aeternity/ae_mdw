defmodule AeMdw.Error do
  defmodule Input do

    defexception [:message]

    defmodule Id do
      def exception(value: value),
        do: %AeMdw.Error.Input{message: "invalid id: #{inspect value}"}
    end

    defmodule TxType do
      def exception(value: value),
        do: %AeMdw.Error.Input{message: "invalid transaction type: #{inspect value}"}
    end

    defmodule Scope do
      def exception(value: {scope, kind, mod}),
        do: %AeMdw.Error.Input{message: "invalid #{inspect kind} scope: #{inspect scope} on #{inspect mod}"}
    end
  end
end

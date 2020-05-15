defmodule AeMdw.Error do
  defmodule Input do
    defexception [:message]

    def struct(prefix, val),
      do: %AeMdw.Error.Input{message: AeMdwWeb.Util.concat(prefix, val)}

    defmodule Id do
      def exception(value: value), do: Input.struct("invalid id", value)
    end

    defmodule NonnegInt do
      def exception(value: value), do: Input.struct("invalid non-negative integer", value)
    end

    defmodule TxField do
      def exception(value: value), do: Input.struct("invalid transaction field", value)
    end

    defmodule TxType do
      def exception(value: value), do: Input.struct("invalid transaction type", value)
    end

    defmodule TxGroup do
      def exception(value: value), do: Input.struct("invalid transaction group", value)
    end

    defmodule Scope do
      def exception(value: value), do: Input.struct("invalid scope", value)
    end

    defmodule Query do
      def exception(value: value), do: Input.struct("invalid query", value)
    end
  end
end

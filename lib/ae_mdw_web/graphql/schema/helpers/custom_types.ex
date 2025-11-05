defmodule AeMdwWeb.GraphQL.Schema.Helpers.CustomTypes do
  use Absinthe.Schema.Notation

  enum :direction do
    value(:forward)
    value(:backward)
  end

  scalar :big_int, name: "BigInt" do
    parse(fn
      %Absinthe.Blueprint.Input.Integer{value: v} ->
        {:ok, v}

      %Absinthe.Blueprint.Input.String{value: v} ->
        case Integer.parse(v) do
          {int, ""} -> {:ok, int}
          _ -> :error
        end

      _ ->
        :error
    end)

    serialize(fn
      v when is_integer(v) ->
        v

      v when is_binary(v) ->
        case Integer.parse(v) do
          {int, ""} -> int
          _ -> raise Absinthe.SerializationError, "Invalid BigInt binary"
        end

      other ->
        raise Absinthe.SerializationError, "Invalid BigInt value: #{inspect(other)}"
    end)
  end

  # Generic JSON passthrough scalar
  scalar :json, name: "JSON" do
    parse(fn
      %{value: value} -> {:ok, value}
      _ -> :error
    end)

    serialize(fn value -> value end)
  end
end

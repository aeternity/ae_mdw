defmodule AeMdwWeb.DataStreamPlug do
  alias AeMdw.Validate

  @spec parse_range(binary()) :: {:ok, Range.t()} | {:error, binary}
  def parse_range(range) do
    case String.split(range, "-") do
      [from, to] ->
        case {Validate.nonneg_int(from), Validate.nonneg_int(to)} do
          {{:ok, from}, {:ok, to}} -> {:ok, from..to}
          {{:ok, _}, {:error, {_, detail}}} -> {:error, detail}
          {{:error, {_, detail}}, _} -> {:error, detail}
        end

      [x] ->
        case Validate.nonneg_int(x) do
          {:ok, x} -> {:ok, x..x}
          {:error, {_, detail}} -> {:error, detail}
        end

      _invalid_range ->
        {:error, range}
    end
  end
end

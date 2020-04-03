defmodule AeMdw.Util do
  def id(x), do: x

  def one!([x]), do: x
  def one!([]), do: raise(ArgumentError, message: "got empty list")
  def one!(err), do: raise(ArgumentError, message: "got #{inspect(err)}")

  def map_one([x], f), do: f.(x)
  def map_one([], _), do: {:error, :not_found}
  def map_one(_, _), do: {:error, :too_many}

  def map_one!([x], f), do: f.(x)
  def map_one!([], _), do: raise(ArgumentError, message: "got empty list")
  def map_one!(err, _), do: raise(ArgumentError, message: "got #{inspect(err)}")

  def ok!({:ok, x}), do: x
  def ok!(err), do: raise(RuntimeError, message: "failed on #{inspect(err)}")

  def map_ok({:ok, x}, f), do: f.(x)
  def map_ok(error, _), do: error

  def map_ok!({:ok, x}, f), do: f.(x)
  def map_ok!(err, _), do: raise(RuntimeError, message: "failed on #{inspect(err)}")

  def flip_tuple({a, b}), do: {b, a}

  def inverse(%{} = map),
    do: Enum.reduce(map, %{}, fn {k, v}, map -> put_in(map[v], k) end)

  def prx(x),
    do: x |> IO.inspect(pretty: true, limit: :infinity)
  def prx(x, label),
    do: x |> IO.inspect(label: label, pretty: true, limit: :infinity)

  def is_mapset(%{__struct__: MapSet}), do: true
  def is_mapset(_), do: false

  def to_list_like(nil), do: [nil]
  def to_list_like(xs), do: (is_mapset(xs) or is_list(xs)) && xs || List.wrap(xs)

end

defmodule AeMdw.Util do

  def id(x), do: x

  def one!([x]), do: x
  def one!([]),  do: raise ArgumentError, message: "got empty list"
  def one!(err), do: raise ArgumentError, message: "got #{inspect err}"

  def map_one([x], f), do: f.(x)
  def map_one([], _),  do: {:error, :not_found}
  def map_one(_, _),   do: {:error, :too_many}

  def map_one!([x], f), do: f.(x)
  def map_one!([], _),  do: raise ArgumentError, message: "got empty list"
  def map_one!(err, _), do: raise ArgumentError, message: "got #{inspect err}"

  def ok!({:ok, x}), do: x
  def ok!(err),      do: raise RuntimeError, message: "failed on #{inspect err}"

  def map_ok({:ok, x}, f), do: f.(x)
  def map_ok(error, _),    do: error

  def map_ok!({:ok, x}, f), do: f.(x)
  def map_ok!(err, _),      do: raise RuntimeError, message: "failed on #{inspect err}"

end

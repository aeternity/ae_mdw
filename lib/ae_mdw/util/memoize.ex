defmodule AeMdw.Util.Memoize do
  @moduledoc """
  Utility to memoize function values.
  """

  defmacro defmemo({name, _location, args} = fundef, do: body) do
    mod = __MODULE__
    caller_mod = __CALLER__.module

    quote do
      def unquote(fundef) do
        cache_key = {unquote(caller_mod), unquote(name), [unquote_splicing(args)]}
        unquote(mod).memo(cache_key, fn -> unquote(body) end)
      end
    end
  end

  defmacro defmemop({name, _location, args} = fundef, do: body) do
    mod = __MODULE__
    caller_mod = __CALLER__.module

    quote do
      defp unquote(fundef) do
        cache_key = {unquote(caller_mod), unquote(name), [unquote_splicing(args)]}
        unquote(mod).memo(cache_key, fn -> unquote(body) end)
      end
    end
  end

  @spec memo(term(), (-> term())) :: term()
  def memo(key, value_fn) do
    with nil <- :persistent_term.get(key, nil) do
      value = value_fn.()
      :persistent_term.put(key, value)
      value
    end
  end
end

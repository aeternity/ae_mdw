defmodule AeMdw.Db.Stream.Resource.Util do
  # credo:disable-for-this-file
  alias AeMdw.Db.Util

  ##########

  def advance_fn(succ, key_checker) do
    fn tab, key ->
      case succ.(tab, key) do
        :none ->
          {:halt, :eot}

        {:ok, next_key} ->
          case key_checker.(next_key) do
            true -> {:cont, next_key}
            false -> {:halt, :keychk}
          end
      end
    end
  end

  ##########

  def simple_resource(init_state, tab, mapper) do
    Stream.resource(
      fn -> init_state end,
      fn {x, advance} -> do_simple(tab, x, advance, mapper) end,
      &AeMdw.Util.id/1
    )
  end

  defp do_simple(_tab, _key, nil, _mapper),
    do: {:halt, :done}

  defp do_simple(tab, key, advance, mapper) do
    case {Util.read(tab, key), advance.(tab, key)} do
      {[x], {:cont, next_key}} ->
        case mapper.(x) do
          nil -> do_simple(tab, next_key, advance, mapper)
          val -> {[val], {next_key, advance}}
        end

      {[], {:cont, next_key}} ->
        do_simple(tab, next_key, advance, mapper)

      {[x], {:halt, _}} ->
        case mapper.(x) do
          nil -> {:halt, :done}
          val -> {[val], {:eot, nil}}
        end

      {[], {:halt, _}} ->
        {:halt, :done}
    end
  end
end

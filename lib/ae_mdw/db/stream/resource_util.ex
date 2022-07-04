defmodule AeMdw.Db.Stream.Resource.Util do
  # credo:disable-for-this-file
  alias AeMdw.Db.State

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

  def simple_resource(state, init_state, tab, mapper) do
    Stream.resource(
      fn -> init_state end,
      fn {x, advance} -> do_simple(state, tab, x, advance, mapper) end,
      &AeMdw.Util.id/1
    )
  end

  defp do_simple(_state, _tab, _key, nil, _mapper),
    do: {:halt, :done}

  defp do_simple(state, tab, key, advance, mapper) do
    case {State.get(state, tab, key), advance.(tab, key)} do
      {{:ok, x}, {:cont, next_key}} ->
        case mapper.(x) do
          nil -> do_simple(state, tab, next_key, advance, mapper)
          val -> {[val], {next_key, advance}}
        end

      {:not_found, {:cont, next_key}} ->
        do_simple(state, tab, next_key, advance, mapper)

      {{:ok, x}, {:halt, _}} ->
        case mapper.(x) do
          nil -> {:halt, :done}
          val -> {[val], {:eot, nil}}
        end

      {:not_found, {:halt, _}} ->
        {:halt, :done}
    end
  end
end

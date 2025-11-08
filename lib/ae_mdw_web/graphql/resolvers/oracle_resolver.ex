defmodule AeMdwWeb.GraphQL.Resolvers.OracleResolver do
  alias AeMdw.Oracles
  alias AeMdw.Db.State
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdwWeb.GraphQL.Resolvers.Helpers

  def oracle(_p, %{id: id}, %{context: %{state: %State{} = state}}) do
    case AeMdw.Validate.id(id, [:oracle_pubkey]) do
      {:ok, pk} ->
        case Oracles.fetch(state, pk, v3?: true) do
          {:ok, oracle} -> {:ok, oracle |> Helpers.normalize_map()}
          {:error, err} -> {:error, ErrInput.message(err)}
        end

      {:error, err} ->
        {:error, ErrInput.message(err)}
    end
  end

  def oracles(_p, args, %{context: %{state: %State{} = state}}) do
    state_filter = Map.get(args, :state)
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    query =
      case state_filter do
        nil -> %{}
        v when is_atom(v) -> %{"state" => Atom.to_string(v)}
        v -> %{"state" => to_string(v)}
      end

    Oracles.fetch_oracles(state, pagination, scope, query, cursor, [{:v3?, true}])
    |> Helpers.make_page()
  end

  def oracle_queries(_p, %{id: id} = args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    Oracles.fetch_oracle_queries(state, id, pagination, scope, cursor)
    |> Helpers.make_page()
  end

  def oracle_responses(_p, %{id: id} = args, %{context: %{state: state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: scoping does not work as expected
    scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    Oracles.fetch_oracle_responses(state, id, pagination, scope, cursor)
    |> Helpers.make_page()
  end

  def oracle_extends(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    limit = Helpers.clamp_page_limit(Map.get(args, :limit))
    cursor = Map.get(args, :cursor)
    direction = Map.get(args, :direction, :backward)
    from_height = Map.get(args, :from_height)
    to_height = Map.get(args, :to_height)
    # TODO: should scoping be removed here?
    _scope = Helpers.make_scope(from_height, to_height)
    pagination = {direction, false, limit, not is_nil(cursor)}

    Oracles.fetch_oracle_extends(state, id, pagination, cursor)
    |> Helpers.make_page()
  end
end

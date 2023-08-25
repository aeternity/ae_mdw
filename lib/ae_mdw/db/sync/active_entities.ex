defmodule AeMdw.Db.Sync.ActiveEntities do
  @moduledoc """
  Keeps track of active entities.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model

  @typep result :: :ok | :invalid | :error | :abort
  @typep txi :: AeMdw.Txs.txi()
  @typep entrypoint :: AeMdw.Contract.method_name()
  @typep args :: AeMdw.Contract.method_args()

  @transitions :ae_mdw
               |> Application.compile_env(AeMdw.Entities, [])
               |> Enum.reduce(%{}, fn {entity, %{initial: initial_call, final: final_calls}},
                                      acc ->
                 final_transitions = Map.new(final_calls, &{&1, {:final, to_string(entity)}})

                 acc
                 |> Map.put(initial_call, {:initial, to_string(entity)})
                 |> Map.merge(final_transitions)
               end)

  @entity_fname_args_types Application.compile_env(:ae_mdw, AeMdw.EntityCalls, %{})

  @spec track(State.t(), result(), txi(), txi(), entrypoint(), args()) :: State.t()
  def track(state, result, create_txi, txi, fname, args) do
    with :ok <- result,
         transition when is_tuple(transition) <- Map.get(@transitions, fname),
         true <- valid_args?(fname, args) do
      exec_transition(state, create_txi, txi, transition, args)
    else
      _nil_or_false ->
        state
    end
  end

  defp exec_transition(state, create_txi, txi, {:initial, entity_name}, args) do
    m_entity = Model.entity(index: {entity_name, txi, create_txi})
    m_contract_entity = Model.contract_entity(index: {entity_name, create_txi, txi})
    final_args = args |> Enum.take(2) |> Enum.map(& &1.value)
    m_entity_args = Model.entity_args(index: {entity_name, create_txi, final_args}, txi: txi)

    state
    |> State.put(Model.ActiveEntity, m_entity)
    |> State.put(Model.ActiveEntityArgs, m_entity_args)
    |> State.put(Model.ContractEntity, m_contract_entity)
  end

  defp exec_transition(state, create_txi, _txi, {:final, entity_name}, args) do
    final_args = Enum.map(args, & &1.value)

    case State.get(state, Model.ActiveEntityArgs, {entity_name, create_txi, final_args}) do
      {:ok, Model.entity_args(txi: initial_txi)} ->
        state
        |> State.delete(Model.ActiveEntity, {entity_name, initial_txi, create_txi})
        |> State.delete(Model.ActiveEntityArgs, {entity_name, create_txi, final_args})
        |> State.delete(Model.ContractEntity, {entity_name, create_txi, initial_txi})

      _other ->
        state
    end
  end

  defp valid_args?(fname, args) do
    Map.get(@entity_fname_args_types, fname) == Enum.map(args, & &1.type)
  end
end

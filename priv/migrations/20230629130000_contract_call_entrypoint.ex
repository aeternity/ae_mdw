defmodule AeMdw.Migrations.ContractCallEntrypoint do
  # credo:disable-for-this-file
  @moduledoc """
  Index contract calls by entrypoint virtual field.
  """

  alias AeMdw.Collection
  alias AeMdw.Fields
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.State
  alias AeMdw.Node.Db, as: NodeDb

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    tx_count =
      case State.get(state, Model.TypeCount, :contract_call_tx) do
        {:ok, Model.type_count(count: count)} -> count
        :not_found -> 0
      end

    if tx_count > 0 do
      num_tasks = System.schedulers_online() * 4
      amount_per_task = trunc(:math.ceil(tx_count / num_tasks))
      IO.puts("num_tasks=#{num_tasks} amount_per_task=#{amount_per_task}")

      tasks =
        Enum.map(0..(num_tasks - 1), fn i ->
          cursor = {:contract_call_tx, i * amount_per_task}
          boundary = {cursor, {:contract_call_tx, (i + 1) * amount_per_task}}

          Task.async(fn ->
            state
            |> Collection.stream(Model.Type, :forward, boundary, cursor)
            |> Stream.map(fn {:contract_call_tx, txi} ->
              field_pos = Fields.mdw_field_pos("entrypoint")
              fname = get_function_name(state, txi)
              m_entrypoint_field = Model.field(index: {:contract_call_tx, field_pos, fname, txi})
              WriteMutation.new(Model.Field, m_entrypoint_field)
            end)
            |> Enum.to_list()
          end)
        end)

      write_mutations =
        tasks
        |> Task.await_many(60_000 * 30)
        |> List.flatten()

      _state = State.commit(state, write_mutations)
      {:ok, length(write_mutations)}
    else
      {:ok, 0}
    end
  end

  def get_function_name(state, txi) do
    Model.tx(id: tx_hash) = State.fetch!(state, Model.Tx, txi)
    {_block_hash, :contract_call_tx, _singed_tx, tx_rec} = NodeDb.get_tx_data(tx_hash)

    contract_pk =
      tx_rec
      |> :aect_call_tx.contract_id()
      |> NodeDb.id_pubkey()

    create_txi = Origin.tx_index!(state, {:contract, contract_pk})

    Model.contract_call(fun: fname) = State.fetch!(state, Model.ContractCall, {create_txi, txi})
    fname
  end
end

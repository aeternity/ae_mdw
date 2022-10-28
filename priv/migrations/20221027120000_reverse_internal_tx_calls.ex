defmodule AeMdw.Migrations.ReverseInternalTxCalls do
  @moduledoc """
  Fixes the fact that internal calls are in reverse order.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Node
  alias AeMdw.Validate

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    case State.prev(state, Model.Tx, nil) do
      {:ok, total_txis} -> run_with_txis(state, total_txis)
      :none -> {:ok, 0}
    end
  end

  defp run_with_txis(state, total_txis) do
    txis_per_100 = div(total_txis, 100)

    deletion_keys = %{
      Model.IdIntContractCall => [],
      Model.GrpIdIntContractCall => [],
      Model.IdFnameIntContractCall => [],
      Model.GrpIdFnameIntContractCall => []
    }

    {mutations, {_next_percentage, deletion_keys}} =
      state
      |> Collection.stream(Model.IntContractCall, nil)
      |> Stream.chunk_by(fn {call_txi, _local_idx} -> call_txi end)
      |> Enum.flat_map_reduce({txis_per_100, deletion_keys}, fn [{call_txi, _local_idx} | _rest] =
                                                                  call_int_calls,
                                                                {next_percentage, deletion_keys} ->
        last_idx = length(call_int_calls) - 1

        next_percentage =
          if call_txi > next_percentage do
            IO.puts("Processed #{call_txi - 1} of #{total_txis}")
            next_percentage + txis_per_100
          else
            next_percentage
          end

        {mutations, deletion_keys} =
          Enum.map_reduce(call_int_calls, deletion_keys, fn {^call_txi, local_idx} = key,
                                                            deletion_keys ->
            new_idx = last_idx - local_idx

            Model.int_contract_call(
              create_txi: create_txi,
              fname: fname,
              tx: tx
            ) = call = State.fetch!(state, Model.IntContractCall, key)

            new_call = Model.int_contract_call(call, index: {call_txi, new_idx})
            new_grp_call = Model.grp_int_contract_call(index: {create_txi, call_txi, new_idx})
            new_fname_call = Model.fname_int_contract_call(index: {fname, call_txi, new_idx})

            new_fname_grp_call =
              Model.fname_grp_int_contract_call(index: {fname, create_txi, call_txi, new_idx})

            {tx_type, raw_tx} = :aetx.specialize_type(tx)

            {id_mutations, deletion_keys} =
              id_mutations_deletions(call, new_idx, tx_type, raw_tx, deletion_keys)

            {[
               WriteMutation.new(Model.IntContractCall, new_call),
               WriteMutation.new(Model.GrpIntContractCall, new_grp_call),
               WriteMutation.new(Model.FnameIntContractCall, new_fname_call),
               WriteMutation.new(Model.FnameGrpIntContractCall, new_fname_grp_call)
               | id_mutations
             ], deletion_keys}
          end)

        {mutations, {next_percentage, deletion_keys}}
      end)

    mutations = [DeleteKeysMutation.new(deletion_keys) | List.flatten(mutations)]

    _state = State.commit(state, mutations)

    IO.puts("DONE")

    {:ok, length(mutations)}
  end

  defp id_mutations_deletions(
         Model.int_contract_call(
           index: {call_txi, local_idx},
           create_txi: create_txi,
           fname: fname
         ),
         new_idx,
         tx_type,
         raw_tx,
         deletion_keys
       ) do
    tx_type
    |> Node.tx_ids()
    |> Enum.map_reduce(deletion_keys, fn {_field, pos}, deletion_keys ->
      pk = Validate.id!(elem(raw_tx, pos))
      m_id_call = Model.id_int_contract_call(index: {pk, pos, call_txi, new_idx})

      m_grp_id_call =
        Model.grp_id_int_contract_call(index: {create_txi, pk, pos, call_txi, new_idx})

      m_id_fname_call =
        Model.id_fname_int_contract_call(index: {pk, fname, pos, call_txi, new_idx})

      m_grp_id_fname_call =
        Model.grp_id_fname_int_contract_call(
          index: {create_txi, pk, fname, pos, call_txi, new_idx}
        )

      deletion_keys =
        deletion_keys
        |> Map.update!(Model.IdIntContractCall, &[{pk, pos, call_txi, local_idx} | &1])
        |> Map.update!(
          Model.GrpIdIntContractCall,
          &[{create_txi, pk, pos, call_txi, local_idx} | &1]
        )
        |> Map.update!(
          Model.IdFnameIntContractCall,
          &[{pk, fname, pos, call_txi, local_idx} | &1]
        )
        |> Map.update!(
          Model.GrpIdFnameIntContractCall,
          &[{create_txi, pk, fname, pos, call_txi, local_idx} | &1]
        )

      {
        [
          WriteMutation.new(Model.IdIntContractCall, m_id_call),
          WriteMutation.new(Model.GrpIdIntContractCall, m_grp_id_call),
          WriteMutation.new(Model.IdFnameIntContractCall, m_id_fname_call),
          WriteMutation.new(Model.GrpIdFnameIntContractCall, m_grp_id_fname_call)
        ],
        deletion_keys
      }
    end)
  end
end

defmodule AeMdw.Db.IntCallsMutation do
  @moduledoc """
  Given a list of internal calls, creates the appropriate indexes.
  """

  alias AeMdw.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Validate

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:contract_pk, :call_txi, :int_calls]

  @typep int_call() ::
           {Contract.local_idx(), Contract.fname(), Node.tx_type(), Node.tx(), Node.aetx()}
  @type t() :: %__MODULE__{
          contract_pk: Db.pubkey(),
          call_txi: Txs.txi(),
          int_calls: [int_call()]
        }

  @spec new(Db.pubkey(), Txs.txi(), [int_call()]) :: t()
  def new(contract_pk, call_txi, int_calls) do
    %__MODULE__{
      contract_pk: contract_pk,
      call_txi: call_txi,
      int_calls: int_calls
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{contract_pk: contract_pk, call_txi: call_txi, int_calls: int_calls},
        state
      ) do
    create_txi = Origin.tx_index!(state, {:contract, contract_pk})

    int_calls
    |> Enum.reduce(state, fn {local_idx, fname, tx_type, aetx, tx}, state ->
      m_call =
        Model.int_contract_call(
          index: {call_txi, local_idx},
          create_txi: create_txi,
          fname: fname,
          tx: aetx
        )

      m_grp_call = Model.grp_int_contract_call(index: {create_txi, call_txi, local_idx})
      m_fname_call = Model.fname_int_contract_call(index: {fname, call_txi, local_idx})

      m_fname_grp_call =
        Model.fname_grp_int_contract_call(index: {fname, create_txi, call_txi, local_idx})

      state2 =
        state
        |> State.put(Model.IntContractCall, m_call)
        |> State.put(Model.GrpIntContractCall, m_grp_call)
        |> State.put(Model.FnameIntContractCall, m_fname_call)
        |> State.put(Model.FnameGrpIntContractCall, m_fname_grp_call)

      tx_type
      |> Node.tx_ids_positions()
      |> Enum.reduce(state2, fn field_pos, state ->
        pk = Validate.id!(elem(tx, field_pos))
        m_id_call = Model.id_int_contract_call(index: {pk, field_pos, call_txi, local_idx})

        m_grp_id_call =
          Model.grp_id_int_contract_call(index: {create_txi, pk, field_pos, call_txi, local_idx})

        m_id_fname_call =
          Model.id_fname_int_contract_call(index: {pk, fname, field_pos, call_txi, local_idx})

        m_grp_id_fname_call =
          Model.grp_id_fname_int_contract_call(
            index: {create_txi, pk, fname, field_pos, call_txi, local_idx}
          )

        state
        |> State.put(Model.IdIntContractCall, m_id_call)
        |> State.put(Model.GrpIdIntContractCall, m_grp_id_call)
        |> State.put(Model.IdFnameIntContractCall, m_id_fname_call)
        |> State.put(Model.GrpIdFnameIntContractCall, m_grp_id_fname_call)
      end)
    end)
  end
end

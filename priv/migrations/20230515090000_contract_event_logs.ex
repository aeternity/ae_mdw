defmodule AeMdw.Migrations.ContractEventLogs do
  # credo:disable-for-this-file
  @moduledoc """
  Index logs by contract and event.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.State

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    write_mutations =
      state
      |> Collection.stream(Model.EvtContractLog, :forward, nil, nil)
      |> Stream.map(fn {event_hash, call_txi, create_txi, log_idx} ->
        m_ctevt_log = Model.ctevt_contract_log(index: {event_hash, create_txi, call_txi, log_idx})
        WriteMutation.new(Model.CtEvtContractLog, m_ctevt_log)
      end)
      |> Enum.to_list()

    _state = State.commit(state, write_mutations)

    {:ok, length(write_mutations)}
  end
end

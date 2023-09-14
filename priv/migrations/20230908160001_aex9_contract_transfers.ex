defmodule AeMdw.Migrations.Aex9ContractTransfers do
  # credo:disable-for-this-file
  @moduledoc """
  Index aex9 transfers by contract.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Origin
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    mutations =
      state
      |> transfers_boundaries()
      |> Task.async_stream(
        fn key_boundary ->
          state
          |> stream_contract_logs(key_boundary)
          |> Enum.flat_map(fn Model.contract_log(index: {create_txi, txi, idx}, args: args) ->
            [from_pk, to_pk, <<amount::256>>] = args

            m_ct_from =
              Model.aexn_contract_from_transfer(
                index: {create_txi, from_pk, txi, to_pk, amount, idx}
              )

            m_ct_to =
              Model.aexn_contract_to_transfer(
                index: {create_txi, to_pk, txi, from_pk, amount, idx}
              )

            [
              WriteMutation.new(Model.AexnContractFromTransfer, m_ct_from),
              WriteMutation.new(Model.AexnContractToTransfer, m_ct_to)
            ]
          end)
        end,
        timeout: :infinity
      )
      |> Enum.flat_map(fn {:ok, mutations} -> mutations end)

    _state = State.commit_db(state, mutations)

    {:ok, length(mutations)}
  end

  defp stream_contract_logs(state, transfers_keys) do
    state
    |> Collection.stream(Model.EvtContractLog, :forward, transfers_keys, nil)
    |> Stream.map(&State.fetch!(state, Model.EvtContractLog, &1))
    |> Stream.flat_map(fn Model.evt_contract_log(index: {_evt_hash, txi, contract_txi, idx}) ->
      contract_pk = Origin.pubkey!(state, {:contract, contract_txi})

      if State.exists?(state, Model.AexnContract, {:aex9, contract_pk}) do
        [read_log(state, {contract_txi, txi, idx})]
      else
        []
      end
    end)
  end

  defp transfers_boundaries(state) do
    evt_hash = :aec_hash.blake2b_256_hash("Transfer")

    case State.prev(state, Model.EvtContractLog, {evt_hash, nil, nil, nil}) do
      {:ok, {^evt_hash, last_txi, _create_txi, _idx}} ->
        {:ok, {evt_hash, first_txi, _create_txi, _idx}} =
          State.next(state, Model.EvtContractLog, {evt_hash, 0, 0, 0})

        txi_ranges(state, evt_hash, first_txi, last_txi)
        |> Enum.map(fn first..last ->
          {{evt_hash, first, 0, 0}, {evt_hash, last, nil, 0}}
        end)

      _other ->
        []
    end
  end

  defp txi_ranges(state, evt_hash, first_txi, last_txi) do
    Stream.unfold(first_txi, fn range_first ->
      if range_first do
        case State.next(state, Model.EvtContractLog, {evt_hash, range_first, 0, 0}) do
          {:ok, {^evt_hash, next_txi, _create_txi, _idx}} ->
            range_last = min(next_txi + 5_000, last_txi)
            next = if range_last < last_txi, do: range_last + 1

            {range_first..range_last, next}

          _no_transfer ->
            nil
        end
      end
    end)
  end

  defp read_log(state, index) do
    table = Model.ContractLog

    case State.get(state, table, index) do
      {:ok, m_log} ->
        m_log

      :not_found ->
        {:ok, value} = AeMdw.Db.RocksDb.get(table, :sext.encode(index))
        record_type = Model.record(table)

        value
        |> :sext.decode()
        |> Tuple.insert_at(0, index)
        |> Tuple.insert_at(0, record_type)
    end
  end
end

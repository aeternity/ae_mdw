defmodule AeMdw.Migrations.LogsHelper do
  @moduledoc false

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model

  @typep hash :: AeMdw.Node.Db.hash()
  @typep optional_txi :: non_neg_integer() | nil
  @typep optional_idx :: non_neg_integer() | nil
  @typep event_boundary :: {
           {hash(), optional_txi, optional_txi, optional_idx},
           {hash(), optional_txi, optional_txi, optional_idx}
         }

  @doc """
  Returns a list of boundaries for Model.EvtContractLog.
  """
  @spec event_boundaries(State.t(), hash(), non_neg_integer()) :: list()
  def event_boundaries(state, evt_hash, max_range_len \\ 5_000) do
    case State.prev(state, Model.EvtContractLog, {evt_hash, nil, nil, nil}) do
      {:ok, {^evt_hash, last_txi, _create_txi, _idx}} ->
        {:ok, {evt_hash, first_txi, _create_txi, _idx}} =
          State.next(state, Model.EvtContractLog, {evt_hash, 0, 0, 0})

        state
        |> txi_ranges(evt_hash, first_txi, last_txi, max_range_len)
        |> Enum.map(fn first..last//_step ->
          {{evt_hash, first, 0, 0}, {evt_hash, last, nil, 0}}
        end)

      _other ->
        []
    end
  end

  @doc """
  Streams Model.ContractLog records using Model.EvtContractLog boundaries.
  """
  @spec stream_contract_logs_by_events(State.t(), event_boundary()) :: Enumerable.t()
  def stream_contract_logs_by_events(state, key_boundary) do
    state
    |> Collection.stream(Model.EvtContractLog, :forward, key_boundary, nil)
    |> Stream.map(&State.fetch!(state, Model.EvtContractLog, &1))
    |> Stream.map(fn Model.evt_contract_log(index: {_evt_hash, txi, contract_txi, idx}) ->
      State.fetch!(state, Model.ContractLog, {contract_txi, txi, idx})
    end)
  end

  defp txi_ranges(state, evt_hash, first_txi, last_txi, max_range_len) do
    Stream.unfold(first_txi, fn
      nil ->
        nil

      range_first ->
        case State.next(state, Model.EvtContractLog, {evt_hash, range_first, 0, 0}) do
          {:ok, {^evt_hash, next_txi, _create_txi, _idx}} ->
            range_last = min(next_txi + max_range_len, last_txi)
            # credo:disable-for-next-line
            next = if range_last < last_txi, do: range_last + 1

            {range_first..range_last, next}

          _no_transfer ->
            nil
        end
    end)
  end
end

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
      {:ok, last_txi} = State.prev(state, Model.Tx, nil) |> IO.inspect()

      count =
        last_txi
        |> txi_ranges()
        |> Task.async_stream(
          fn first_txi..last_txi ->
            boundary = {{:contract_call_tx, first_txi}, {:contract_call_tx, last_txi}}

            state
            |> Collection.stream(Model.Type, :forward, boundary, nil)
            |> Stream.map(fn {:contract_call_tx, txi} ->
              field_pos = Fields.mdw_field_pos("entrypoint")
              fname = get_function_name(state, txi)
              m_entrypoint_field = Model.field(index: {:contract_call_tx, field_pos, fname, txi})
              WriteMutation.new(Model.Field, m_entrypoint_field)
            end)
            |> Enum.to_list()
          end,
          timeout: :infinity,
          ordered: false
        )
        |> Stream.map(fn
          {:ok, []} ->
            0

          {:ok, mutations} ->
            _state = State.commit(state, mutations)
            length(mutations)
        end)
        |> Enum.sum()

      {:ok, count}
    else
      {:ok, 0}
    end
  end

  defp txi_ranges(last_txi) do
    0
    |> Stream.unfold(fn range_first ->
      if range_first do
        range_last = min(range_first + 5_000, last_txi)
        next = if range_last < last_txi, do: range_last + 1

        {range_first..range_last, next}
      end
    end)
    |> Enum.to_list()
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

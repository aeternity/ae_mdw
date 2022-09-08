defmodule AeMdw.Migrations.Aex141Owners do
  @moduledoc """
  Indexes nft owners by collection.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    state = State.new()
    begin = DateTime.utc_now()

    count =
      state
      |> Collection.stream(Model.AexnTransfer, nil)
      |> Stream.take_while(fn key -> elem(key, 0) == :aex141 end)
      |> Stream.map(&State.fetch!(state, Model.AexnTransfer, &1))
      |> Stream.map(fn Model.aexn_transfer(
                         index: {:aex141, from_pk, txi, to_pk, token_id, i},
                         contract_pk: contract_pk
                       ) ->
        args = [from_pk, to_pk, <<token_id::256>>]
        Contract.write_aex141_records(state, contract_pk, txi, i, args)
        :ok
      end)
      |> Enum.count()

    duration = DateTime.diff(DateTime.utc_now(), begin)

    {:ok, {count, duration}}
  end
end

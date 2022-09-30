defmodule AeMdw.Migrations.Aex141Owners do
  @moduledoc """
  Indexes nft owners by collection.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Origin
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    state = State.new()
    begin = DateTime.utc_now()

    mint_hash = AeMdw.Node.aexn_mint_event_hash()

    mint_count =
      state
      |> Collection.stream(
        Model.EvtContractLog,
        :forward,
        {{mint_hash, -1, -1, -1}, {mint_hash, nil, nil, nil}},
        nil
      )
      |> Enum.filter(fn {_hash, _txi, create_txi, _i} ->
        ct_pk = Origin.pubkey(state, {:contract, create_txi})
        ct_pk != nil and State.exists?(State.new(), Model.AexnContract, {:aex141, ct_pk})
      end)
      |> Enum.map(fn {evt_hash, txi, create_txi, i} ->
        Model.contract_log(args: args) =
          State.fetch!(state, Model.ContractLog, {create_txi, txi, evt_hash, i})

        contract_pk = Origin.pubkey(state, {:contract, create_txi})
        _state = Contract.write_aex141_ownership(state, contract_pk, args)
        :ok
      end)
      |> Enum.count()

    transfer_count =
      state
      |> Collection.stream(Model.AexnTransfer, nil)
      |> Stream.take_while(fn key -> elem(key, 0) == :aex141 end)
      |> Stream.map(&State.fetch!(state, Model.AexnTransfer, &1))
      |> Stream.map(fn Model.aexn_transfer(
                         index: {:aex141, from_pk, _txi, to_pk, token_id, _i},
                         contract_pk: contract_pk
                       ) ->
        args = [from_pk, to_pk, <<token_id::256>>]
        _state = Contract.write_aex141_ownership(state, contract_pk, args)
        :ok
      end)
      |> Enum.count()

    duration = DateTime.diff(DateTime.utc_now(), begin)

    {:ok, {mint_count + transfer_count, duration}}
  end
end

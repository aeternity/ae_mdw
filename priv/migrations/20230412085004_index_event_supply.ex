defmodule AeMdw.Migrations.IndexEventSupply do
  # credo:disable-for-this-file
  @moduledoc """
  Index aex9 intial and event supply.
  """

  alias AeMdw.AexnContracts
  alias AeMdw.Collection
  alias AeMdw.Node.Db, as: NodeDb
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.State

  require Model

  @mint_hash <<215, 0, 247, 67, 100, 22, 167, 140, 76, 197, 95, 144, 242, 214, 49, 111, 60, 169,
               26, 213, 244, 50, 59, 170, 72, 182, 90, 72, 178, 84, 251, 35>>

  @burn_hash <<131, 150, 191, 31, 191, 94, 29, 68, 10, 143, 62, 247, 169, 46, 221, 88, 138, 150,
               176, 154, 87, 110, 105, 73, 173, 237, 42, 252, 105, 193, 146, 6>>

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    key_boundary = {{@mint_hash, 0, 0, 0}, {@mint_hash, nil, nil, nil}}
    mint_stream = Collection.stream(state, Model.EvtContractLog, :forward, key_boundary, nil)
    key_boundary = {{@burn_hash, 0, 0, 0}, {@burn_hash, nil, nil, nil}}
    burn_stream = Collection.stream(state, Model.EvtContractLog, :forward, key_boundary, nil)

    write_mutations =
      [mint_stream, burn_stream]
      |> Collection.merge(:forward)
      |> Stream.flat_map(fn {event_hash, call_txi, create_txi, log_idx} ->
        contract_pk = Origin.pubkey(state, {:contract, create_txi}) || <<>>

        if AexnContracts.is_aex9?(contract_pk) do
          case State.fetch!(state, Model.ContractLog, {create_txi, call_txi, event_hash, log_idx}) do
            Model.contract_log(args: [_account_pk, <<amount::256>>]) ->
              if event_hash == @mint_hash,
                do: [{contract_pk, amount}],
                else: [{contract_pk, -amount}]

            _other ->
              []
          end
        else
          []
        end
      end)
      |> Enum.group_by(fn {pk, _amount} -> pk end)
      |> Enum.flat_map(fn {pk, list} ->
        create_txi = Origin.tx_index!(state, {:contract, pk})
        Model.tx(block_index: {kbi, mbi}) = State.fetch!(state, Model.Tx, create_txi)
        Model.block(hash: next_kb_hash) = State.fetch!(state, Model.Block, {kbi + 1, -1})
        mb_hash = NodeDb.get_next_hash(next_kb_hash, mbi)

        create_sum =
          case NodeDb.aex9_balances(pk, {:micro, kbi, mb_hash}) do
            {:ok, addr_map} ->
              addr_map |> Enum.map(fn {_addr, balance} -> balance end) |> Enum.sum()

            {:error, _reason} ->
              0
          end

        event_sum = list |> Enum.map(fn {_pk, amount} -> amount end) |> Enum.sum()

        [
          WriteMutation.new(
            Model.Aex9ContractBalance,
            Model.aex9_contract_balance(index: pk, amount: event_sum)
          ),
          WriteMutation.new(
            Model.Aex9InitialSupply,
            Model.aex9_initial_supply(index: pk, amount: create_sum)
          )
        ]
      end)

    _state = State.commit(state, write_mutations)

    {:ok, length(write_mutations)}
  end
end

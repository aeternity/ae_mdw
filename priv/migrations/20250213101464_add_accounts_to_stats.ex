defmodule AeMdw.Migrations.AddAccountsToStats do
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Collection
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Sync.Transaction
  alias AeMdw.Blocks

  import Record

  require Model

  defrecord :delta_stat,
    index: 0,
    auctions_started: 0,
    names_activated: 0,
    names_expired: 0,
    names_revoked: 0,
    oracles_registered: 0,
    oracles_expired: 0,
    contracts_created: 0,
    block_reward: 0,
    dev_reward: 0,
    locked_in_auctions: 0,
    burned_in_auctions: 0,
    channels_opened: 0,
    channels_closed: 0,
    locked_in_channels: 0

  defrecord :total_stat,
    index: 0,
    block_reward: 0,
    dev_reward: 0,
    total_supply: 0,
    active_auctions: 0,
    active_names: 0,
    inactive_names: 0,
    active_oracles: 0,
    inactive_oracles: 0,
    contracts: 0,
    locked_in_auctions: 0,
    burned_in_auctions: 0,
    locked_in_channels: 0,
    open_channels: 0

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    top = State.height(state)

    delta_count = 0

    Model.Block
    |> RocksDbCF.stream(
      direction: :forward,
      key_boundary: Collection.generate_key_boundary()
    )
    |> Stream.filter(fn Model.block(index: {_height, mbi}) ->
      mbi == -1
    end)
    |> Task.async_stream(
      fn Model.block(index: {height, _mbi}) ->
        kb =
          Collection.generate_key_boundary({height, Collection.integer()})

        accounts_count =
          Model.Block
          |> RocksDbCF.stream(key_boundary: kb)
          |> Stream.filter(fn Model.block(index: {^height, mbi}) ->
            mbi != -1
          end)
          |> Enum.reduce(MapSet.new(), fn Model.block(index: {^height, mbi}, hash: hash),
                                          accounts_acc ->
            state
            |> State.get(Model.DeltaStat, height)
            |> case do
              {:ok, _delta_stat} ->
                IO.inspect({height, mbi}, label: "height, mbi")

                {:value, mb} =
                  :aec_db.find_block(hash)

                txs_accounts =
                  mb
                  |> :aec_blocks.txs()
                  |> Enum.flat_map(fn signed_tx ->
                    signed_tx
                    |> Transaction.get_ids_from_tx()
                    |> Enum.flat_map(fn
                      {:id, :account, pubkey} -> [pubkey]
                      _other -> []
                    end)
                  end)
                  |> MapSet.new()

                int_contract_calls_accounts =
                  state
                  |> Blocks.fetch_txis_from_gen(height)
                  |> Enum.map(fn txi ->
                    ["Chain.spend", "Call.amount"]
                    |> Enum.map(fn fname ->
                      kb = Collection.generate_key_boundary({fname, txi, Collection.integer()})
                      RocksDbCF.stream(Model.FnameIntContractCall, key_boundary: kb)
                    end)
                    |> Stream.concat()
                    |> Enum.map(fn Model.fname_int_contract_call(
                                     index: {_fname, call_txi, local_id}
                                   ) ->
                      Model.int_contract_call(tx: aetx) =
                        State.fetch!(state, Model.IntContractCall, {call_txi, local_id})

                      {tx_type, tx_rec} = :aetx.specialize_type(aetx)

                      tx_type
                      |> AeMdw.Node.tx_ids_positions()
                      |> Enum.map(&elem(tx_rec, &1))
                      |> Enum.flat_map(fn
                        {:id, :account, pubkey} -> [pubkey]
                        _other -> []
                      end)
                    end)
                  end)
                  |> MapSet.new()

                accounts_acc
                |> MapSet.union(txs_accounts)
                |> MapSet.union(int_contract_calls_accounts)
            end
          end)
          |> Enum.reduce(0, fn pubkey, acc ->
            state
            |> State.get(Model.AccountCreation, pubkey)
            |> case do
              :not_found ->
                acc + 1

              _account_creation ->
                acc
            end
          end)

        state
        |> State.get(Model.DeltaStat, height)
        |> case do
          {:ok,
           delta_stat(
             index: index,
             auctions_started: auctions_started,
             names_activated: names_activated,
             names_expired: names_expired,
             names_revoked: names_revoked,
             oracles_registered: oracle_registered,
             oracles_expired: oracles_expired,
             contracts_created: contracts_created,
             block_reward: block_reward,
             dev_reward: dev_reward,
             locked_in_auctions: locked_in_auctions,
             burned_in_auctions: burned_in_auctions,
             channels_opened: channels_opened,
             channels_closed: channels_closed,
             locked_in_channels: locked_in_channels
           )} ->
            new_delta_stat =
              Model.delta_stat(
                index: index,
                auctions_started: auctions_started,
                names_activated: names_activated,
                names_expired: names_expired,
                names_revoked: names_revoked,
                oracles_registered: oracle_registered,
                oracles_expired: oracles_expired,
                contracts_created: contracts_created,
                block_reward: block_reward,
                dev_reward: dev_reward,
                locked_in_auctions: locked_in_auctions,
                burned_in_auctions: burned_in_auctions,
                channels_opened: channels_opened,
                channels_closed: channels_closed,
                locked_in_channels: locked_in_channels,
                accounts: accounts_count
              )

            WriteMutation.new(Model.DeltaStat, new_delta_stat)

          {:ok, _delta_stat} ->
            nil
        end
      end,
      timeout: :infinity
    )
    |> Stream.map(fn {:ok, mutation} -> mutation end)
    |> Stream.chunk_every(1000)
    |> Enum.reduce(0, fn mutations, counter ->
      _acc_state = State.commit_db(state, mutations)

      counter + length(mutations)
    end)

    IO.inspect(delta_count, label: "delta_count")

    total_stat_count =
      Model.TotalStat
      |> RocksDbCF.stream()
      |> Enum.reduce({0, []}, fn
        total_stat(
          index: index,
          block_reward: block_reward,
          dev_reward: dev_reward,
          total_supply: total_supply,
          active_auctions: active_auctions,
          active_names: active_names,
          inactive_names: inactive_names,
          active_oracles: active_oracles,
          inactive_oracles: inactive_oracles,
          contracts: contracts,
          locked_in_auctions: locked_in_auctions,
          burned_in_auctions: burned_in_auctions,
          locked_in_channels: locked_in_channels,
          open_channels: open_channels
        ),
        {count_acc, mutations} ->
          delta_accounts_count =
            case State.get(state, Model.DeltaStat, index) do
              {:ok, Model.delta_stat(accounts: delta_accounts_count)} ->
                delta_accounts_count

              :not_found when index == top + 1 ->
                0
            end

          accounts_count = delta_accounts_count + count_acc

          new_total_stat =
            Model.total_stat(
              index: index,
              block_reward: block_reward,
              dev_reward: dev_reward,
              total_supply: total_supply,
              active_auctions: active_auctions,
              active_names: active_names,
              inactive_names: inactive_names,
              active_oracles: active_oracles,
              inactive_oracles: inactive_oracles,
              contracts: contracts,
              locked_in_auctions: locked_in_auctions,
              burned_in_auctions: burned_in_auctions,
              locked_in_channels: locked_in_channels,
              open_channels: open_channels,
              accounts: accounts_count
            )

          {accounts_count, [WriteMutation.new(Model.TotalStat, new_total_stat) | mutations]}
      end)
      |> then(fn {_accounts_count, mutations} ->
        mutations
        |> Stream.chunk_every(1000)
        |> Stream.map(fn mutations ->
          _acc_state = State.commit_db(state, mutations)

          length(mutations)
        end)
        |> Enum.sum()
      end)

    IO.inspect(total_stat_count, label: "total_stat_count")

    IO.inspect({:ok, delta_count + total_stat_count})
  end
end

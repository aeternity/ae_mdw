defmodule AeMdw.Db.StateTest do
  use ExUnit.Case, async: false

  alias AeMdw.AsyncTaskTestUtil
  alias AeMdw.Database
  alias AeMdw.Db.Aex9BalancesCache
  alias AeMdw.Db.AexnCreateContractMutation
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.MemStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.NullStore
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Sync.AsyncTasks.Store

  require Model

  import Mock

  @kb_hash :crypto.strong_rand_bytes(32)
  @next_hash :crypto.strong_rand_bytes(32)

  setup_with_mocks([
    {AeMdw.Node.Db, [],
     [
       get_key_block_hash: fn _height -> @kb_hash end,
       get_next_hash: fn _kb_hash, _mbi -> @next_hash end
     ]}
  ]) do
    :ok
  end

  describe "commit_db" do
    test "persists db-only aex9 tasks and saves results into database" do
      ct_pk = :crypto.strong_rand_bytes(32)
      block_index = {567_890, 2}
      call_txi = 12_345_678

      account_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(1_000_000_000..9_999_999_999)
      balances = %{{:address, account_pk} => amount}

      Aex9BalancesCache.put(ct_pk, block_index, @next_hash, balances)

      State.new()
      |> State.enqueue(:update_aex9_state, [ct_pk], [block_index, call_txi])
      |> State.commit_db([WriteMutation.new(Model.Block, Model.block(index: block_index))], false)

      tasks =
        Model.AsyncTask
        |> Database.all_keys()
        |> Enum.map(fn key -> Database.fetch!(Model.AsyncTask, key) end)

      assert Enum.any?(tasks, fn
               Model.async_task(
                 index: {_ts, :update_aex9_state},
                 args: [^ct_pk],
                 extra_args: [^block_index, ^call_txi]
               ) ->
                 true

               _other ->
                 false
             end)

      AsyncTaskTestUtil.wakeup_consumers()

      assert Enum.any?(1..10, fn _i ->
               Process.sleep(100)

               match?(
                 {:ok,
                  Model.aex9_account_presence(
                    index: {^account_pk, ^ct_pk},
                    txi: ^call_txi
                  )},
                 Database.fetch(Model.Aex9AccountPresence, {account_pk, ct_pk})
               )
             end)

      task_index =
        Enum.find_value(tasks, fn Model.async_task(index: index, args: args) ->
          if args == [ct_pk], do: index
        end)

      refute Database.exists?(Model.AsyncTask, task_index)
    end

    test "doesn't enqueue aex9 task again after enqueued by on-memory sync" do
      ct_pk = :crypto.strong_rand_bytes(32)
      block_index = {567_890, 2}
      call_txi = 12_345_679

      Aex9BalancesCache.put(ct_pk, block_index, @next_hash, %{
        {:address, :crypto.strong_rand_bytes(32)} => <<>>
      })

      dedup_args = [ct_pk]
      extra_args = [block_index, call_txi]

      NullStore.new()
      |> MemStore.new()
      |> State.new()
      |> State.enqueue(:update_aex9_state, dedup_args, extra_args)
      |> State.commit_mem([])

      AsyncTaskTestUtil.wakeup_consumers()

      assert {task_index, _time} =
               AeMdw.EtsCache.get(
                 :async_tasks_added,
                 {:update_aex9_state, dedup_args, extra_args}
               )

      assert Enum.any?(1..10, fn _i ->
               Process.sleep(100)

               nil ==
                 Enum.find(Store.fetch_unprocessed(), fn Model.async_task(args: args) ->
                   args == dedup_args
                 end)
             end)

      State.new()
      |> State.enqueue(:update_aex9_state, dedup_args, extra_args)
      |> State.commit_db([WriteMutation.new(Model.Block, Model.block(index: block_index))], false)

      assert {^task_index, _time} =
               AeMdw.EtsCache.get(
                 :async_tasks_added,
                 {:update_aex9_state, dedup_args, extra_args}
               )
    end
  end

  describe "commit_mem" do
    test "saves multiple aex9 task results into ets store" do
      block_index = {567_891, 2}
      call_txi = 12_345_680

      account_pk = :crypto.strong_rand_bytes(32)
      amount = Enum.random(1_000_000_000..9_999_999_999)
      balances = %{{:address, account_pk} => amount}

      ct_pks =
        Enum.map(1..100, fn _i ->
          ct_pk = :crypto.strong_rand_bytes(32)
          Aex9BalancesCache.put(ct_pk, block_index, @next_hash, balances)
          ct_pk
        end)

      mutations =
        Enum.map(ct_pks, fn ct_pk ->
          AexnCreateContractMutation.new(
            :aex9,
            ct_pk,
            {"mem_aex9", "mem_aex9", 18},
            block_index,
            call_txi,
            []
          )
        end)

      NullStore.new()
      |> MemStore.new()
      |> State.new()
      |> State.commit_mem(mutations)

      assert Enum.all?(ct_pks, fn ct_pk ->
               AeMdw.EtsCache.member(
                 :async_tasks_added,
                 {:update_aex9_state, [ct_pk], [block_index, call_txi]}
               )
             end)

      AsyncTaskTestUtil.wakeup_consumers()

      async_state = State.new(AsyncStore.instance())

      all_presence_keys = Enum.map(ct_pks, fn ct_pk -> {account_pk, ct_pk} end)

      assert [] ==
               Enum.reduce_while(1..100, all_presence_keys, fn _i, presences_keys ->
                 Process.sleep(100)

                 found =
                   Enum.filter(
                     presences_keys,
                     &State.exists?(async_state, Model.Aex9AccountPresence, &1)
                   )

                 case presences_keys -- found do
                   [] -> {:halt, []}
                   remaining -> {:cont, remaining}
                 end
               end)

      assert Enum.all?(ct_pks, fn ct_pk ->
               balance_key = {ct_pk, account_pk}

               match?(
                 {:ok,
                  Model.aex9_balance(
                    index: ^balance_key,
                    block_index: ^block_index,
                    txi: ^call_txi,
                    amount: ^amount
                  )},
                 State.get(async_state, Model.Aex9Balance, balance_key)
               )
             end)
    end
  end
end

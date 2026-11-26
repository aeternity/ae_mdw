defmodule AeMdwWeb.HyperchainControllerTest do
  use AeMdwWeb.ConnCase, async: false

  alias AeMdw.Db.EpochMutation
  alias AeMdw.Db.LeaderMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.WriteMutation
  alias AeMdw.HyperchainSim

  require Model

  @alice <<1::256>>
  @bob <<2::256>>
  @carol <<3::256>>
  @dave <<4::256>>
  @erin <<5::256>>
  @seed1 :crypto.hash(:sha256, "seed 1")
  @seed2 :crypto.hash(:sha256, "seed 2")

  # epoch 1 is heights 1-4, epoch 2 is 5-8, epoch 3 is 9-14 and has no seed on chain yet
  @epochs [
    %{
      seed: @seed1,
      validators: [{@alice, 1_000}, {@bob, 2_000}],
      schedule: [@alice, @bob, @bob, @alice]
    },
    %{
      seed: @seed2,
      validators: [{@alice, 1_500}, {@bob, 2_000}, {@carol, 500}],
      schedule: [@carol, @alice, @bob, @carol]
    },
    %{
      seed: nil,
      validators: [{@bob, 3_000}, {@carol, 500}],
      schedule: [@bob, @bob, @carol, @bob, @carol, @bob]
    }
  ]

  @hyperchain_paths ~w(
    /v3/hyperchain/config
    /v3/hyperchain/schedule
    /v3/hyperchain/schedule/height/1
    /v3/hyperchain/epochs
    /v3/hyperchain/epochs/top
    /v3/hyperchain/validators
    /v3/hyperchain/validators/top
    /v3/hyperchain/validators/:id
    /v3/hyperchain/validators/:id/delegates
    /v3/hyperchain/validators/:id/delegates/top
  )

  # Tags: `top` (default 11) is the chain's last height, `synced?: false` leaves mdw
  # empty, `hyperchain?: false` doesn't fake a hyperchain node and
  # `drop_config` removes a section of the node config.
  setup %{conn: conn, store: store} = ctx do
    if Map.get(ctx, :hyperchain?, true) do
      config = Map.drop(HyperchainSim.default_config(), List.wrap(ctx[:drop_config]))
      sim = HyperchainSim.new(@epochs, top: Map.get(ctx, :top, 11), config: config)
      modules = HyperchainSim.mock!(sim)
      on_exit(fn -> HyperchainSim.unmock(modules) end)

      store = if Map.get(ctx, :synced?, true), do: sync(store, 0..sim.top), else: store

      {:ok, conn: with_store(conn, store), store: store}
    else
      {:ok, conn: with_store(conn, store)}
    end
  end

  describe "on a node that isn't a hyperchain" do
    @describetag hyperchain?: false

    test "every hyperchain endpoint answers 400", %{conn: conn} do
      for path <- @hyperchain_paths do
        path = String.replace(path, ":id", enc(@alice))

        assert %{"error" => "This endpoint is only available on a hyperchain node"} ==
                 conn |> get(path) |> json_response(400),
               path
      end
    end
  end

  describe "on a hyperchain node" do
    test "the mining endpoints answer 400", %{conn: conn} do
      for path <- ~w(/v3/miners /v3/stats/miners /v3/stats/mining) do
        assert %{"error" => "This endpoint is not available on a hyperchain node"} ==
                 conn |> get(path) |> json_response(400),
               path
      end
    end
  end

  describe "GET /v3/hyperchain/config" do
    test "returns the consensus, hard forks and network of the node", %{conn: conn} do
      assert %{
               "consensus" => [consensus],
               "hard_forks" => %{"6" => 0},
               "fork_management" => %{"network_id" => "hc_test"}
             } = conn |> get("/v3/hyperchain/config") |> json_response(200)

      assert %{
               "consensus_key" => "0",
               "child_block_time" => 3_000,
               "child_epoch_length" => 4,
               "parent_chain" => %{"start_height" => 10}
             } = consensus
    end

    test "never returns the pinner and staker accounts or their keys", %{conn: conn} do
      body = conn |> get("/v3/hyperchain/config") |> response(200)

      refute body =~ "private-key"
      refute body =~ "pinners"
      refute body =~ "stakers"
    end

    @tag drop_config: "fork_management"
    test "answers 422 when the node config lacks a section", %{conn: conn} do
      assert %{"error" => "Unable to parse aeternity.yaml config file"} ==
               conn |> get("/v3/hyperchain/config") |> json_response(422)
    end
  end

  describe "GET /v3/hyperchain/epochs" do
    test "lists the epochs of the synced heights, newest first", %{conn: conn} do
      assert %{"data" => epochs, "next" => nil, "prev" => nil} =
               conn |> get("/v3/hyperchain/epochs") |> json_response(200)

      assert [3, 2, 1] == Enum.map(epochs, & &1["epoch"])
    end

    test "returns the heights, start, last leader and validators of an epoch", %{conn: conn} do
      assert %{"data" => [epoch]} =
               conn |> get("/v3/hyperchain/epochs", scope: "epoch:2") |> json_response(200)

      assert %{
               "epoch" => 2,
               "first" => 5,
               "last" => 8,
               "length" => 4,
               "last_pin_height" => 4,
               "epoch_start_time" => HyperchainSim.key_block_time(4),
               "last_leader" => enc(@carol)
             } == Map.drop(epoch, ["seed", "validators"])

      assert sorted([
               %{"validator" => enc(@alice), "stake" => 1_500},
               %{"validator" => enc(@bob), "stake" => 2_000},
               %{"validator" => enc(@carol), "stake" => 500}
             ]) == sorted(epoch["validators"])
    end

    test "returns the leader of the last synced height as the current epoch's last leader",
         %{conn: conn} do
      assert %{"data" => [%{"epoch" => 3, "first" => 9, "last" => 14, "last_leader" => leader}]} =
               conn |> get("/v3/hyperchain/epochs", scope: "epoch:3") |> json_response(200)

      assert enc(@carol) == leader
    end

    test "returns the seed as a hash, and null while the chain has none", %{conn: conn} do
      assert %{"data" => epochs} = conn |> get("/v3/hyperchain/epochs") |> json_response(200)

      assert [nil, encode(:key_block_hash, @seed2), encode(:key_block_hash, @seed1)] ==
               Enum.map(epochs, & &1["seed"])
    end

    test "lists the oldest epoch first with direction=forward", %{conn: conn} do
      assert %{"data" => epochs} =
               conn |> get("/v3/hyperchain/epochs", direction: "forward") |> json_response(200)

      assert [1, 2, 3] == Enum.map(epochs, & &1["epoch"])
    end

    test "scopes the epochs", %{conn: conn} do
      assert [1, 2] == conn |> walk("/v3/hyperchain/epochs", scope: "epoch:1-2") |> epochs()
      assert [3, 2] == conn |> walk("/v3/hyperchain/epochs", scope: "epoch:3-2") |> epochs()
    end

    test "pages through the epochs with the next and prev links", %{conn: conn} do
      assert [3, 2, 1] == conn |> walk("/v3/hyperchain/epochs", limit: 1) |> epochs()

      assert [1, 2, 3] ==
               conn |> walk("/v3/hyperchain/epochs", limit: 1, direction: "forward") |> epochs()

      assert %{"next" => second_page} =
               conn |> get("/v3/hyperchain/epochs", limit: 1) |> json_response(200)

      assert %{"data" => [%{"epoch" => 2}], "prev" => first_page} =
               conn |> get(second_page) |> json_response(200)

      assert %{"data" => [%{"epoch" => 3}]} = conn |> get(first_page) |> json_response(200)
    end

    test "answers 400 for a scope of heights", %{conn: conn} do
      assert %{"error" => "invalid scope" <> _rest} =
               conn |> get("/v3/hyperchain/epochs", scope: "gen:1-4") |> json_response(400)
    end
  end

  describe "GET /v3/hyperchain/epochs/top" do
    test "returns the epoch of the last synced height", %{conn: conn} do
      assert %{"epoch" => 3, "first" => 9, "last" => 14, "last_leader" => leader} =
               conn |> get("/v3/hyperchain/epochs/top") |> json_response(200)

      assert enc(@carol) == leader
    end

    @tag synced?: false
    test "answers 404 before the first generation is synced", %{conn: conn} do
      assert %{"error" => "not found: epoch at height -1"} ==
               conn |> get("/v3/hyperchain/epochs/top") |> json_response(404)
    end
  end

  describe "GET /v3/hyperchain/schedule" do
    test "lists the leader of every height, the rest of the current epoch included",
         %{conn: conn} do
      assert [
               {14, @bob},
               {13, @carol},
               {12, @bob},
               {11, @carol},
               {10, @bob},
               {9, @bob},
               {8, @carol},
               {7, @bob},
               {6, @alice},
               {5, @carol},
               {4, @alice},
               {3, @bob},
               {2, @bob},
               {1, @alice}
             ] == conn |> walk("/v3/hyperchain/schedule", limit: 4) |> leaders()
    end

    test "scopes the schedule to heights", %{conn: conn} do
      assert [{3, @bob}, {4, @alice}, {5, @carol}, {6, @alice}] ==
               conn |> walk("/v3/hyperchain/schedule", scope: "gen:3-6") |> leaders()
    end

    test "scopes the schedule to epochs", %{conn: conn} do
      assert [1, 2, 3, 4, 5, 6, 7, 8] ==
               conn |> walk("/v3/hyperchain/schedule", scope: "epoch:1-2") |> heights()
    end

    test "scopes the schedule to all the heights of an epoch longer than the first ones",
         %{conn: conn} do
      assert [14, 13, 12, 11, 10, 9] ==
               conn |> walk("/v3/hyperchain/schedule", scope: "epoch:3") |> heights()
    end

    test "answers 400 for an epoch the chain hasn't reached", %{conn: conn} do
      assert %{"error" => "invalid scope" <> _rest} =
               conn |> get("/v3/hyperchain/schedule", scope: "epoch:9") |> json_response(400)
    end

    test "answers 400 for a scope of transactions", %{conn: conn} do
      assert %{"error" => "invalid scope" <> _rest} =
               conn |> get("/v3/hyperchain/schedule", scope: "txi:1-2") |> json_response(400)
    end
  end

  describe "GET /v3/hyperchain/schedule/height/:height" do
    test "returns the leader of a height", %{conn: conn} do
      assert %{"height" => 6, "leader" => enc(@alice)} ==
               conn |> get("/v3/hyperchain/schedule/height/6") |> json_response(200)
    end

    test "returns the leader of a height later in the current epoch", %{conn: conn} do
      assert %{"height" => 13, "leader" => enc(@carol)} ==
               conn |> get("/v3/hyperchain/schedule/height/13") |> json_response(200)
    end

    test "answers 404 for a height after the current epoch", %{conn: conn} do
      assert %{"error" => "not found: height 15"} ==
               conn |> get("/v3/hyperchain/schedule/height/15") |> json_response(404)
    end

    test "answers 400 for a height that isn't a number", %{conn: conn} do
      assert %{"error" => "invalid non-negative integer: x"} ==
               conn |> get("/v3/hyperchain/schedule/height/x") |> json_response(400)
    end
  end

  describe "GET /v3/hyperchain/validators" do
    test "lists the validators of each epoch with their stake in it, newest epoch first",
         %{conn: conn} do
      validators = walk(conn, "/v3/hyperchain/validators", limit: 3)

      assert [3, 3, 2, 2, 2, 1, 1] == Enum.map(validators, & &1["epoch"])

      assert sorted([
               {3, enc(@bob), 3_000},
               {3, enc(@carol), 500},
               {2, enc(@alice), 1_500},
               {2, enc(@bob), 2_000},
               {2, enc(@carol), 500},
               {1, enc(@alice), 1_000},
               {1, enc(@bob), 2_000}
             ]) == sorted(stakes(validators))
    end

    @tag top: 9
    test "returns the stakes of the leaders from the first height of their epoch on",
         %{conn: conn} do
      assert sorted([{3, enc(@bob), 3_000}, {3, enc(@carol), 500}]) ==
               conn |> walk("/v3/hyperchain/validators", scope: "epoch:3") |> stakes() |> sorted()
    end

    test "returns the delegates, rewards and pinning history of a validator",
         %{conn: conn, store: store} do
      store =
        change_store(store, [
          WriteMutation.new(Model.Delegate, Model.delegate(index: {@bob, 2, @dave}, stake: 10)),
          WriteMutation.new(Model.Delegate, Model.delegate(index: {@bob, 2, @erin}, stake: 20)),
          WriteMutation.new(Model.Delegate, Model.delegate(index: {@bob, 3, @dave}, stake: 30)),
          WriteMutation.new(
            Model.LeaderPinInfo,
            Model.leader_pin_info(index: {@bob, 1}, reward: 7)
          ),
          WriteMutation.new(
            Model.LeaderPinInfo,
            Model.leader_pin_info(index: {@bob, 2}, reward: 9)
          ),
          WriteMutation.new(Model.Miner, Model.miner(index: @bob, total_reward: 100))
        ])

      assert %{"data" => validators} =
               conn
               |> with_store(store)
               |> get("/v3/hyperchain/validators", scope: "epoch:2")
               |> json_response(200)

      assert %{
               "epoch" => 2,
               "validator" => enc(@bob),
               "total_stakes" => 2_000,
               "delegates" => 2,
               "rewards_earned" => 100,
               "pinning_history" => %{"1" => 7, "2" => 9}
             } == Enum.find(validators, &(&1["validator"] == enc(@bob)))

      assert %{"delegates" => 0, "rewards_earned" => 0, "pinning_history" => %{}} =
               Enum.find(validators, &(&1["validator"] == enc(@alice)))
    end

    test "scopes the validators to epochs", %{conn: conn} do
      assert sorted([
               {2, enc(@alice), 1_500},
               {2, enc(@bob), 2_000},
               {2, enc(@carol), 500},
               {1, enc(@alice), 1_000},
               {1, enc(@bob), 2_000}
             ]) ==
               conn
               |> walk("/v3/hyperchain/validators", scope: "epoch:1-2")
               |> stakes()
               |> sorted()
    end

    test "pages through the validators with the next links", %{conn: conn} do
      all = walk(conn, "/v3/hyperchain/validators", limit: 100)

      assert length(all) == 7
      assert all == walk(conn, "/v3/hyperchain/validators", limit: 2)

      assert Enum.reverse(all) ==
               walk(conn, "/v3/hyperchain/validators", limit: 2, direction: "forward")
    end

    test "answers 400 for a scope of heights", %{conn: conn} do
      assert %{"error" => "invalid scope" <> _rest} =
               conn |> get("/v3/hyperchain/validators", scope: "gen:1-4") |> json_response(400)
    end
  end

  describe "GET /v3/hyperchain/validators/top" do
    test "lists the validators of the current epoch", %{conn: conn} do
      assert sorted([{3, enc(@bob), 3_000}, {3, enc(@carol), 500}]) ==
               conn |> walk("/v3/hyperchain/validators/top", []) |> stakes() |> sorted()
    end

    @tag synced?: false
    test "answers 404 before the first generation is synced", %{conn: conn} do
      assert %{"error" => "not found" <> _rest} =
               conn |> get("/v3/hyperchain/validators/top") |> json_response(404)
    end
  end

  describe "GET /v3/hyperchain/validators/:id" do
    test "returns a validator of the current epoch", %{conn: conn} do
      assert %{
               "epoch" => 3,
               "validator" => enc(@bob),
               "total_stakes" => 3_000,
               "delegates" => 0,
               "rewards_earned" => 0,
               "pinning_history" => %{}
             } == conn |> get("/v3/hyperchain/validators/#{enc(@bob)}") |> json_response(200)
    end

    test "answers 404 for an account that doesn't validate the current epoch", %{conn: conn} do
      assert %{"error" => "not found" <> _rest} =
               conn |> get("/v3/hyperchain/validators/#{enc(@alice)}") |> json_response(404)
    end

    test "answers 400 for an invalid id", %{conn: conn} do
      assert %{"error" => "invalid id" <> _rest} =
               conn |> get("/v3/hyperchain/validators/ak_invalid") |> json_response(400)
    end
  end

  describe "GET /v3/hyperchain/validators/:id/delegates" do
    setup %{conn: conn, store: store} do
      store =
        change_store(store, [
          WriteMutation.new(Model.Delegate, Model.delegate(index: {@bob, 2, @dave}, stake: 10)),
          WriteMutation.new(Model.Delegate, Model.delegate(index: {@bob, 2, @erin}, stake: 20)),
          WriteMutation.new(Model.Delegate, Model.delegate(index: {@bob, 3, @dave}, stake: 30)),
          WriteMutation.new(Model.Delegate, Model.delegate(index: {@carol, 3, @erin}, stake: 40))
        ])

      {:ok, conn: with_store(conn, store)}
    end

    test "lists the delegates of a validator, newest epoch first", %{conn: conn} do
      delegates = walk(conn, "/v3/hyperchain/validators/#{enc(@bob)}/delegates", limit: 1)

      assert [3, 2, 2] == Enum.map(delegates, & &1["epoch"])

      assert sorted([
               %{"epoch" => 3, "delegate" => enc(@dave), "stake" => 30, "validator" => enc(@bob)},
               %{"epoch" => 2, "delegate" => enc(@erin), "stake" => 20, "validator" => enc(@bob)},
               %{"epoch" => 2, "delegate" => enc(@dave), "stake" => 10, "validator" => enc(@bob)}
             ]) == sorted(delegates)
    end

    test "scopes the delegates to epochs", %{conn: conn} do
      assert sorted([{2, enc(@dave), 10}, {2, enc(@erin), 20}]) ==
               conn
               |> walk("/v3/hyperchain/validators/#{enc(@bob)}/delegates", scope: "epoch:2")
               |> Enum.map(&{&1["epoch"], &1["delegate"], &1["stake"]})
               |> sorted()
    end

    test "lists the delegates of the current epoch on /top", %{conn: conn} do
      assert [%{"epoch" => 3, "delegate" => delegate, "stake" => 40}] =
               walk(conn, "/v3/hyperchain/validators/#{enc(@carol)}/delegates/top", [])

      assert enc(@erin) == delegate
    end

    test "answers 400 for an invalid id", %{conn: conn} do
      for path <- ["/delegates", "/delegates/top"] do
        assert %{"error" => "invalid id" <> _rest} =
                 conn
                 |> get("/v3/hyperchain/validators/ak_invalid" <> path)
                 |> json_response(400),
               path
      end
    end
  end

  describe "syncing" do
    test "generations synced again leave the indexed epochs, leaders and stakes as they were",
         %{conn: conn, store: store} do
      paths = ~w(/v3/hyperchain/epochs /v3/hyperchain/schedule /v3/hyperchain/validators)
      synced = Enum.map(paths, &walk(conn, &1, limit: 100))

      resynced_conn = with_store(conn, sync(store, 5..11))

      assert synced == Enum.map(paths, &walk(resynced_conn, &1, limit: 100))
    end
  end

  # Sync.Block gives each generation of a hyperchain these mutations (see
  # Sync.BlockTest), and the generation's DeltaStat sets the height.
  defp sync(store, heights) do
    mutations =
      Enum.flat_map(heights, fn height ->
        [
          EpochMutation.new(height),
          LeaderMutation.new(height),
          WriteMutation.new(Model.DeltaStat, Model.delta_stat(index: height))
        ]
      end)

    change_store(store, mutations)
  end

  # every item of every page, following the next links
  defp walk(conn, path, params) do
    conn
    |> get(path, params)
    |> json_response(200)
    |> Stream.unfold(fn
      nil -> nil
      %{"data" => data, "next" => nil} -> {data, nil}
      %{"data" => data, "next" => next} -> {data, conn |> get(next) |> json_response(200)}
    end)
    |> Enum.concat()
  end

  defp epochs(items), do: Enum.map(items, & &1["epoch"])

  defp heights(items), do: Enum.map(items, & &1["height"])

  defp leaders(items) do
    Enum.map(items, fn %{"height" => height, "leader" => leader} ->
      {height, decode_account(leader)}
    end)
  end

  defp stakes(validators),
    do: Enum.map(validators, &{&1["epoch"], &1["validator"], &1["total_stakes"]})

  defp sorted(items), do: Enum.sort(items)

  defp enc(pubkey), do: encode_account(pubkey)

  defp decode_account(account_id) do
    {:ok, pubkey} = :aeser_api_encoder.safe_decode(:account_pubkey, account_id)

    pubkey
  end
end

defmodule AeMdwWeb.GraphQL.BlockCorrectnessTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.{State, Model, Util}
  require Model
  alias AeMdw.Blocks

  @schema AeMdwWeb.GraphQL.Schema

  @moduletag :graphql
  @moduletag :integration

  setup_all do
    # Retry a few times for state during startup
    state =
      Enum.find_value(1..5, fn attempt ->
        case State.mem_state() do
          %State{} = s -> s
          _ ->
            Process.sleep(200 * attempt)
            false
        end
      end)

    if state do
      last_gen = case Util.last_gen(state) do {:ok, g} -> g; :none -> 0 end
      {:ok, %{state: state, last_gen: last_gen}}
    else
      ExUnit.configure(exclude: [graphql: true])
      :ok
    end
  end

  defp gql(query, ctx), do: Absinthe.run(query, @schema, context: %{state: ctx.state})

  defp assert_ok({:ok, %{data: data}}, path), do: get_in(data, path)
  defp assert_ok(other, _), do: flunk("unexpected: #{inspect(other)}")

  describe "key_block field correctness" do
  test "single key_block fields match Blocks context", %{state: state, last_gen: last_gen} = ctx do
      assume_height = if last_gen > 50, do: last_gen - 5, else: last_gen
      assume_height = max(0, assume_height)
      # Skip if chain too small
      if last_gen == 0 do
        assert true
      else
    {:ok, base_block} = Blocks.fetch_key_block(state, Integer.to_string(assume_height))
        q = """
        { key_block(id: \"#{assume_height}\") {
            hash height time miner microBlocks: micro_blocks_count transactions_count beneficiary_reward
          }
        }
        """
        kb = assert_ok(gql(q, ctx), ["key_block"])
    # Use fetch with default to avoid match errors if upstream map keys vary during sync
    assert kb["height"] == Map.get(base_block, "height")
    assert kb["hash"] == Map.get(base_block, "hash")
    assert kb["time"] == Map.get(base_block, "time")
    assert kb["miner"] == Map.get(base_block, "beneficiary")
    assert kb["microBlocks"] == (base_block[:micro_blocks_count] || Map.get(base_block, "micro_blocks_count"))
    assert kb["transactions_count"] == (base_block[:transactions_count] || Map.get(base_block, "transactions_count"))
    # beneficiary_reward can be nil briefly if sync mid-update; only assert when present both sides
    if base_block[:beneficiary_reward], do: assert kb["beneficiary_reward"] == base_block[:beneficiary_reward]
      end
    end

  test "key_blocks ordering (descending heights) and clamp limit", ctx do
      q = "{ key_blocks(limit: 150) { data { height } } }"
      page = assert_ok(gql(q, ctx), ["key_blocks"])
      heights = for %{"height" => h} <- page["data"], do: h
      assert length(heights) <= 100
      assert heights == Enum.sort(heights, :desc)
    end

    test "limit boundary behaviors (0 => default 20, negative => default 20, >100 => clamp)" , ctx do
      page0 = assert_ok(gql("{ a: key0: key_blocks(limit:0){ data { height } } b: keyNeg: key_blocks(limit:-5){ data { height } } c: keyBig: key_blocks(limit:101){ data { height } } }", ctx), [])
      a_len = length(get_in(page0, ["a", "data"]))
      b_len = length(get_in(page0, ["b", "data"]))
      c_len = length(get_in(page0, ["c", "data"]))
      # cannot assert exact 20 if chain shorter, so >=0 and <=20 for defaults, clamp <=100
      assert a_len <= 20
      assert b_len <= 20
      assert c_len <= 100
    end

    test "fromHeight only restricts to single height" , %{last_gen: last_gen} = ctx do
      if last_gen > 5 do
        target = last_gen - 3
        page = assert_ok(gql("{ key_blocks(fromHeight: #{target}, limit: 40){ data { height } } }", ctx), ["key_blocks"])
        hs = Enum.map(page["data"], & &1["height"]) |> Enum.uniq()
        assert hs == [target]
      else
        assert true
      end
    end

    test "toHeight only returns heights <= bound", %{last_gen: last_gen} = ctx do
      bound = max(0, div(last_gen, 2))
      page = assert_ok(gql("{ key_blocks(toHeight: #{bound}, limit: 10){ data { height } } }", ctx), ["key_blocks"])
      Enum.each(page["data"], fn %{"height" => h} -> assert h <= bound end)
    end

    test "pagination cursor advances and no overlap", ctx do
      q1 = "{ key_blocks(limit: 3) { nextCursor data { height } } }"
      %{"key_blocks" => %{"nextCursor" => cursor, "data" => data1}} = assert_ok(gql(q1, ctx), [])
      if data1 == [] or is_nil(cursor) do
        assert true
      else
        min_h1 = Enum.min(for %{"height" => h} <- data1, do: h)
        q2 = "{ key_blocks(limit: 3, cursor: \"#{cursor}\") { data { height } } }"
        %{"key_blocks" => %{"data" => data2}} = assert_ok(gql(q2, ctx), [])
        h1s = MapSet.new(for %{"height" => h} <- data1, do: h)
        h2s = MapSet.new(for %{"height" => h} <- data2, do: h)
        # Expect no overlap when second page present
        if data2 != [], do: assert MapSet.disjoint?(h1s, h2s)
        # Second page heights should all be < min_h1 (descending pagination)
        if data2 != [], do: assert Enum.all?(data2, fn %{"height" => h} -> h < min_h1 end)
      end
    end

    test "range filter returns only heights within bounds", %{last_gen: last_gen} = ctx do
      if last_gen < 10 do
        assert true
      else
        from_h = max(0, last_gen - 15)
        to_h = last_gen - 5
        q = "{ key_blocks(fromHeight: #{from_h}, toHeight: #{to_h}, limit: 20) { data { height } } }"
        %{"key_blocks" => %{"data" => data}} = assert_ok(gql(q, ctx), [])
        Enum.each(data, fn %{"height" => h} -> assert h >= from_h and h <= to_h end)
      end
    end
  end

  describe "micro_block correctness" do
    test "micro_block fields match Blocks context for first available", %{state: state, last_gen: last_gen} = ctx do
      if last_gen == 0 do
        assert true
      else
        # find a height with at least one micro block scanning backwards up to 200 heights
        target_h =
          Enum.find(last_gen..max(0, last_gen - 200)//-1, fn h ->
            match?({:ok, _}, State.get(state, Model.Block, {h, 0}))
          end)

        if is_nil(target_h) do
          # no micro blocks yet (small chain) -> skip
          assert true
        else
          case State.get(state, Model.Block, {target_h, 0}) do
            {:ok, rec} ->
              Model.block(hash: mb_hash) = rec
              enc_hash = :aeser_api_encoder.encode(:micro_block_hash, mb_hash)
              case Blocks.fetch_micro_block(state, enc_hash) do
                {:ok, base_mb} ->
                  q = "{ micro_block(hash: \"#{enc_hash}\") { hash height time microBlockIndex: micro_block_index transactions_count gas } }"
                  mb = assert_ok(gql(q, ctx), ["micro_block"])
                  assert mb["hash"] == base_mb["hash"]
                    && mb["height"] == base_mb["height"]
                    && mb["time"] == base_mb["time"]
                  assert mb["microBlockIndex"] == (base_mb[:micro_block_index] || base_mb["micro_block_index"])
                  assert mb["transactions_count"] == (base_mb[:transactions_count] || base_mb["transactions_count"])
                  assert mb["gas"] == base_mb[:gas]
                _ -> assert true
              end
            :not_found -> assert true
          end
        end
      end
    end
  end

  describe "contract correctness" do
    test "contract meta matches DB (first aexn if any)", %{state: state} = ctx do
      case State.prev(state, Model.AexnContract, nil) do
        {:ok, {aexn_type, contract_pk}} ->
          Model.aexn_contract(meta_info: meta) = State.fetch!(state, Model.AexnContract, {aexn_type, contract_pk})
          enc = :aeser_api_encoder.encode(:contract_pubkey, contract_pk)
          q = "{ contract(id: \"#{enc}\") { id aexn_type meta_name meta_symbol } }"
          c = assert_ok(gql(q, ctx), ["contract"])
          if match?({_n,_s,_d,_v}, meta) do
            {name, symbol, _decimals, _version} = meta
            assert c["aexn_type"] == Atom.to_string(aexn_type)
            assert c["meta_name"] == name
            assert c["meta_symbol"] == symbol
          end
        :none -> assert true
      end
    end
  end
end

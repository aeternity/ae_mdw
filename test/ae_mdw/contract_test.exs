defmodule AeMdw.ContractTest do
  use ExUnit.Case

  alias AeMdw.Contract
  alias AeMdw.EtsCache

  import Mock

  describe "call_tx_info/3" do
    test "it returns :error when contract call ret type is :error" do
      block_hash = <<0::256>>
      contract_pk = <<1::256>>
      account_id = :aeser_id.create(:account, <<2::256>>)
      contract_id = :aeser_id.create(:contract, contract_pk)

      call_data =
        <<43, 17, 137, 194, 198, 79, 27, 47, 2, 29, 85, 83, 68, 84, 85, 83, 68, 111, 131, 15, 68,
          213, 25, 66, 84, 67, 85, 83, 68, 111, 133, 8, 153, 224, 185, 96>>

      ct_info =
        {{:fcode,
          %{
            <<68, 214, 68, 31>> =>
              {[], {[], {:tuple, []}},
               %{
                 0 => [
                   {:STORE, {:var, -1}, {:immediate, %{}}},
                   {:RETURNR, {:immediate, {:tuple, {}}}}
                 ]
               }},
            <<137, 194, 198, 79>> =>
              {[], {[{:map, :string, :integer}], {:tuple, []}},
               %{
                 0 => [
                   {:STORE, {:var, -1}, {:arg, 0}},
                   {:RETURNR, {:immediate, {:tuple, {}}}}
                 ]
               }},
            <<242, 61, 75, 108>> =>
              {[], {[:string], {:variant, [tuple: [], tuple: [:integer]]}},
               %{
                 0 => [
                   {:STORE, {:var, 0}, {:var, -1}},
                   {:MAP_MEMBER, {:stack, 0}, {:var, -1}, {:arg, 0}},
                   {:JUMPIF, {:stack, 0}, {:immediate, 2}}
                 ],
                 1 => [RETURNR: {:immediate, {:variant, [0, 1], 0, {}}}],
                 2 => [
                   {:MAP_LOOKUP, {:stack, 0}, {:var, 0}, {:arg, 0}},
                   {:VARIANT, {:stack, 0}, {:immediate, [0, 1]}, {:immediate, 1},
                    {:immediate, 1}},
                   :RETURN
                 ]
               }}
          },
          %{
            <<68, 214, 68, 31>> => "init",
            <<137, 194, 198, 79>> => "fulfill",
            <<242, 61, 75, 108>> => "get_price"
          }, %{}}, "6.1.0",
         <<2, 103, 8, 248, 133, 237, 74, 109, 39, 26, 123, 35, 66, 194, 182, 216, 94, 206, 24,
           202, 187, 242, 135, 194, 61, 67, 179, 242, 70, 76, 63, 199>>}

      EtsCache.put(Contract, contract_pk, ct_info)

      {:ok, call_aetx} =
        :aect_call_tx.new(%{
          caller_id: account_id,
          nonce: 1,
          contract_id: contract_id,
          abi_version: 1,
          fee: 1,
          amount: 1,
          gas: 1,
          gas_price: 1,
          call_data: call_data
        })

      {:contract_call_tx, call_tx} = :aetx.specialize_type(call_aetx)
      call_id = :aect_call_tx.call_id(call_tx)

      call = :aect_call.new(account_id, 1, contract_id, call_id, 1, 1)
      call = :aect_call.set_return_type(:error, call)

      with_mocks [
        {:aec_chain, [],
         [
           get_contract_call: fn ^contract_pk, ^call_id, ^block_hash -> {:ok, call} end
         ]}
      ] do
        assert {:error, ^call} =
                 Contract.call_tx_info(call_tx, contract_pk, contract_pk, block_hash)
      end
    end

    test "when ret type is :revert, it doesn't return an error" do
      block_hash = <<0::256>>
      contract_pk = <<1::256>>
      account_id = :aeser_id.create(:account, <<2::256>>)
      contract_id = :aeser_id.create(:contract, contract_pk)

      call_data =
        <<43, 17, 137, 194, 198, 79, 27, 111, 137, 5, 10, 162, 95, 67, 207, 83, 255, 192>>

      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 2>>

      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 2>>

      ct_info =
        {{:fcode,
          %{
            <<9, 211, 66, 225>> =>
              {[:private], {[:string], {:bytes, 32}},
               %{0 => [{:SHA3, {:stack, 0}, {:arg, 0}}, :RETURN]}},
            <<23, 4, 130, 49>> =>
              {[:private], {[:string], :integer},
               %{
                 0 => [
                   PUSH: {:var, -1},
                   TIMESTAMP: {:stack, 0},
                   CALL: {:immediate, <<41, 224, 239, 178>>}
                 ],
                 1 => [
                   {:SUB, {:stack, 0}, {:stack, 0}, {:stack, 0}},
                   {:ADD, {:stack, 0}, {:stack, 0}, {:stack, 0}},
                   :RETURN
                 ]
               }},
            <<29, 16, 246, 255>> => {[], {[], :integer}, %{0 => [RETURNR: {:var, -4}]}},
            <<31, 149, 242, 206>> =>
              {[], {[:string], :boolean},
               %{0 => [{:MAP_MEMBER, {:stack, 0}, {:var, -2}, {:arg, 0}}, :RETURN]}},
            " 9l\\" => {[], {[], :address}, %{0 => [{:CALLER, {:stack, 0}}, :RETURN]}},
            <<41, 224, 239, 178>> =>
              {[:private], {[], :integer},
               %{
                 0 => [
                   {:GENERATION, {:stack, 0}},
                   :DECA,
                   {:BLOCKHASH, {:var, 0}, {:stack, 0}},
                   {:SWITCH_V2, {:var, 0}, {:immediate, 2}, {:immediate, 1}}
                 ],
                 1 => [
                   {:VARIANT_ELEMENT, {:var, 1}, {:var, 0}, {:immediate, 0}},
                   {:BYTES_TO_INT, {:stack, 0}, {:var, 1}},
                   :RETURN
                 ],
                 2 => [ABORT: {:immediate, "blockhash not found"}]
               }},
            <<55, 5, 250, 186>> =>
              {[], {[:string], {:tuple, []}},
               %{
                 0 => [PUSH: {:arg, 0}, CALL: {:immediate, <<31, 149, 242, 206>>}],
                 1 => [
                   {:NOT, {:stack, 0}, {:stack, 0}},
                   {:JUMPIF, {:stack, 0}, {:immediate, 3}}
                 ],
                 2 => [ABORT: {:immediate, "Name is already taken"}],
                 3 => [PUSH: {:arg, 0}, CALL: {:immediate, <<23, 4, 130, 49>>}],
                 4 => [PUSH: {:arg, 0}, CALL_T: {:immediate, <<219, 1, 131, 45>>}]
               }},
            <<68, 214, 68, 31>> =>
              {[], {[], {:tuple, []}},
               %{
                 0 => [
                   {:STORE, {:var, -2}, {:immediate, %{}}},
                   {:CALLER, {:var, -5}},
                   {:STORE, {:var, -1}, {:immediate, 1}},
                   {:STORE, {:var, -3}, {:immediate, 42}},
                   {:STORE, {:var, -4}, {:immediate, 0}},
                   {:RETURNR, {:immediate, {:tuple, {}}}}
                 ]
               }},
            <<102, 184, 140, 137>> =>
              {[], {[:integer, :integer], :integer},
               %{0 => [{:ADD, {:var, -3}, {:arg, 0}, {:arg, 1}}, {:RETURNR, {:var, -3}}]}},
            <<110, 79, 208, 251>> =>
              {[], {[:integer, :integer], :integer},
               %{
                 0 => [
                   {:ADD, {:var, -3}, {:arg, 0}, {:arg, 1}},
                   {:ADD, {:stack, 0}, {:arg, 0}, {:arg, 1}},
                   :RETURN
                 ]
               }},
            <<123, 147, 107, 76>> =>
              {[], {[], {:tuple, []}}, %{0 => [ABORT: {:immediate, "require failed"}]}},
            <<137, 194, 198, 79>> =>
              {[], {[:integer], {:tuple, []}},
               %{
                 0 => [
                   {:CALLER, {:stack, 0}},
                   {:EQ, {:stack, 0}, {:stack, 0}, {:var, -5}},
                   {:JUMPIF, {:stack, 0}, {:immediate, 2}}
                 ],
                 1 => [ABORT: {:immediate, "not allowed"}],
                 2 => [
                   {:STORE, {:var, -4}, {:arg, 0}},
                   {:RETURNR, {:immediate, {:tuple, {}}}}
                 ]
               }},
            <<146, 139, 32, 54>> =>
              {[], {[:string], {:bytes, 32}},
               %{0 => [PUSH: {:arg, 0}, CALL_T: {:immediate, <<9, 211, 66, 225>>}]}},
            <<169, 8, 152, 70>> =>
              {[], {[:string, {:variant, [tuple: [], tuple: [:integer]]}], :integer},
               %{
                 0 => [PUSH: {:arg, 0}, CALL: {:immediate, <<31, 149, 242, 206>>}],
                 1 => [{:JUMPIF, {:stack, 0}, {:immediate, 3}}],
                 2 => [ABORT: {:immediate, "There is no hamster with that name!"}],
                 3 => [
                   {:STORE, {:var, 2}, {:var, -2}},
                   {:MAP_LOOKUP, {:var, 3}, {:var, 2}, {:arg, 0}},
                   {:ELEMENT, {:stack, 0}, {:immediate, 2}, {:var, 3}},
                   :RETURN
                 ]
               }},
            <<202, 186, 253, 210>> => {[], {[], :address}, %{0 => [RETURNR: {:var, -5}]}},
            <<219, 1, 131, 45>> =>
              {[:private], {[:string, :integer], {:tuple, []}},
               %{
                 0 => [
                   {:PUSH, {:var, -1}},
                   {:PUSH, {:arg, 0}},
                   {:PUSH, {:arg, 1}},
                   {:TUPLE, {:stack, 0}, {:immediate, 3}},
                   {:POP, {:var, 1}},
                   {:MAP_UPDATE, {:var, -2}, {:var, -2}, {:arg, 0}, {:var, 1}},
                   {:INC, {:var, -1}},
                   {:RETURNR, {:immediate, {:tuple, {}}}}
                 ]
               }},
            <<247, 180, 176, 134>> =>
              {[], {[:integer, :integer], :integer},
               %{0 => [{:ADD, {:stack, 0}, {:arg, 0}, {:arg, 1}}, :RETURN]}},
            <<252, 182, 91, 178>> =>
              {[], {[:address], :address},
               %{
                 0 => [
                   {:CALLER, {:stack, 0}},
                   {:EQ, {:stack, 0}, {:stack, 0}, {:var, -5}},
                   {:JUMPIF, {:stack, 0}, {:immediate, 2}}
                 ],
                 1 => [ABORT: {:immediate, "not allowed"}],
                 2 => [{:STORE, {:var, -5}, {:arg, 0}}, {:RETURNR, {:var, -5}}]
               }}
          },
          %{
            <<9, 211, 66, 225>> => ".String.sha3",
            <<23, 4, 130, 49>> => ".OracleTest.generate_random_dna",
            <<29, 16, 246, 255>> => "readPrice",
            <<31, 149, 242, 206>> => "name_exists",
            " 9l\\" => "return_caller",
            <<41, 224, 239, 178>> => ".OracleTest.get_block_hash_bytes_as_int",
            <<55, 5, 250, 186>> => "create_hamster",
            <<68, 214, 68, 31>> => "init",
            <<102, 184, 140, 137>> => "statefully_add_two",
            <<110, 79, 208, 251>> => "add_test_value",
            <<123, 147, 107, 76>> => "cause_error",
            <<137, 194, 198, 79>> => "fulfill",
            <<146, 139, 32, 54>> => "test",
            <<169, 8, 152, 70>> => "get_hamster_dna",
            <<202, 186, 253, 210>> => "getOracleSource",
            <<219, 1, 131, 45>> => ".OracleTest.create_hamster_by_name_dna",
            <<247, 180, 176, 134>> => "locally_add_two",
            <<252, 182, 91, 178>> => "setOracleSource"
          }, %{}}, "7.4.0",
         <<36, 179, 103, 139, 101, 231, 183, 72, 167, 241, 71, 152, 177, 203, 24, 255, 137, 141,
           242, 223, 101, 87, 68, 181, 236, 111, 217, 98, 189, 217, 145, 135>>}

      EtsCache.put(Contract, contract_pk, ct_info)

      {:ok, call_aetx} =
        :aect_call_tx.new(%{
          caller_id: account_id,
          nonce: 1,
          contract_id: contract_id,
          abi_version: 1,
          fee: 1,
          amount: 1,
          gas: 1,
          gas_price: 1,
          call_data: call_data
        })

      {:contract_call_tx, call_tx} = :aetx.specialize_type(call_aetx)
      call_id = :aect_call_tx.call_id(call_tx)

      call = :aect_call.new(account_id, 1, contract_id, call_id, 1, 1)
      call = :aect_call.set_return_type(:revert, call)

      with_mocks [
        {:aec_chain, [],
         [
           get_contract_call: fn ^contract_pk, ^call_id, ^block_hash -> {:ok, call} end
         ]}
      ] do
        assert {%{
                  arguments: [%{type: :int, value: 93_000_000_000_000_000_000}],
                  function: "fulfill",
                  result: :invalid
                }, ^call} = Contract.call_tx_info(call_tx, contract_pk, contract_pk, block_hash)
      end
    end
  end

  describe "maybe_resolve_contract_pk/2" do
    setup do
      contract_pk = <<1::256>>

      name_pk =
        <<217, 52, 92, 99, 90, 59, 250, 112, 123, 114, 18, 135, 95, 95, 205, 71, 74, 160, 14, 22,
          47, 119, 229, 124, 220, 96, 81, 40, 117, 5, 23, 138>>

      fake_mb = "mh_2XGZtE8jxUs2NymKHsytkaLLrk6KY2t2w1FjJxtAUqYZn8Wsdd"

      success_mock =
        {:aens, [],
         [
           resolve_hash: fn "contract_pubkey", ^name_pk, _block ->
             {:ok, {:id, :contract, contract_pk}}
           end
         ]}

      fail_mock =
        {:aens, [],
         [
           resolve_hash: fn "contract_pubkey", ^name_pk, _block ->
             {:error, :name_not_resolved}
           end
         ]}

      common_mocks = [
        {:aec_db, [],
         [
           get_block_state: fn _block_hash -> {:ok, %{}} end
         ]},
        {:aec_trees, [],
         [
           ns: fn _ns_tree -> {:ok, %{}} end
         ]}
      ]

      %{
        contract_pk: contract_pk,
        name_pk: name_pk,
        fake_mb: fake_mb,
        success_mocks: [success_mock | common_mocks],
        fail_mocks: [fail_mock | common_mocks]
      }
    end

    test "it returns contract_pk when name contains contract_pubkey pointer", %{
      contract_pk: contract_pk,
      name_pk: name_pk,
      fake_mb: fake_mb,
      success_mocks: success_mocks
    } do
      with_mocks(success_mocks) do
        assert ^contract_pk = Contract.maybe_resolve_contract_pk(name_pk, fake_mb)
      end
    end

    test "it returns contract_pk when contract_pk is passed", %{
      contract_pk: contract_pk,
      fake_mb: fake_mb
    } do
      assert ^contract_pk = Contract.maybe_resolve_contract_pk(contract_pk, fake_mb)
    end

    test "it returns :error when contract isn't resolved", %{
      name_pk: name_pk,
      fake_mb: fake_mb,
      fail_mocks: fail_mocks
    } do
      with_mocks fail_mocks do
        assert_raise RuntimeError,
                     "Contract not resolved: #{inspect(name_pk)} with reason :name_not_resolved",
                     fn -> Contract.maybe_resolve_contract_pk(name_pk, fake_mb) end
      end
    end
  end
end

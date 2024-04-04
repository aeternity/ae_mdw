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

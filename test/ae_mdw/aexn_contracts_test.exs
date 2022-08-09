defmodule AeMdw.AexnContractsTest do
  use ExUnit.Case

  alias AeMdw.AexnContracts

  import Mock

  describe "is_aex141?/1" do
    test "returns true for a BaseNFT" do
      contract_pk = :crypto.strong_rand_bytes(32)
      type_info = base_nft_fcode()
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      with_mocks [
        {AeMdw.DryRun.Runner, [],
         [
           call_contract: fn _pk, _hash, "aex141_extensions", [] -> {:ok, []} end
         ]}
      ] do
        assert AexnContracts.is_aex141?(contract_pk)
      end
    end
  end

  defp base_nft_fcode do
    {:fcode,
     %{
       <<4, 167, 206, 191>> =>
         {[:private], {[:boolean], :string},
          %{
            0 => [{:JUMPIF, {:arg, 0}, {:immediate, 2}}],
            1 => [RETURNR: {:immediate, "false"}],
            2 => [RETURNR: {:immediate, "true"}]
          }},
       <<15, 27, 134, 79>> =>
         {[:private], {[], {:tuple, []}},
          %{
            0 => [
              {:CALLER, {:stack, 0}},
              {:EQ, {:stack, 0}, {:stack, 0}, {:var, -1}},
              {:JUMPIF, {:stack, 0}, {:immediate, 2}}
            ],
            1 => [ABORT: {:immediate, "ONLY_CONTRACT_OWNER_CALL_ALLOWED"}],
            2 => [RETURNR: {:immediate, {:tuple, {}}}]
          }},
       <<15, 89, 34, 233>> =>
         {[], {[:address, :address], :boolean},
          %{
            0 => [
              {:STORE, {:var, 0}, {:var, -9}},
              {:MAP_MEMBER, {:stack, 0}, {:var, -9}, {:arg, 0}},
              {:JUMPIF, {:stack, 0}, {:immediate, 8}}
            ],
            1 => [
              {:PUSH, {:immediate, {:variant, [0, 1], 0, {}}}},
              {:POP, {:var, 2}},
              {:SWITCH_V2, {:var, 2}, {:immediate, 2}, {:immediate, 3}}
            ],
            2 => [RETURNR: {:immediate, false}],
            3 => [
              {:VARIANT_ELEMENT, {:var, 3}, {:var, 2}, {:immediate, 0}},
              {:MAP_MEMBER, {:stack, 0}, {:var, 3}, {:arg, 1}},
              {:JUMPIF, {:stack, 0}, {:immediate, 7}}
            ],
            4 => [
              {:PUSH, {:immediate, {:variant, [0, 1], 0, {}}}},
              {:POP, {:var, 5}},
              {:SWITCH_V2, {:var, 5}, {:immediate, 5}, {:immediate, 6}}
            ],
            5 => [RETURNR: {:immediate, false}],
            6 => [
              {:VARIANT_ELEMENT, {:stack, 0}, {:var, 5}, {:immediate, 0}},
              :RETURN
            ],
            7 => [
              {:MAP_LOOKUP, {:stack, 0}, {:var, 3}, {:arg, 1}},
              {:VARIANT, {:stack, 0}, {:immediate, [0, 1]}, {:immediate, 1}, {:immediate, 1}},
              {:POP, {:var, 5}},
              {:SWITCH_V2, {:var, 5}, {:immediate, 5}, {:immediate, 6}}
            ],
            8 => [
              {:MAP_LOOKUP, {:stack, 0}, {:var, 0}, {:arg, 0}},
              {:VARIANT, {:stack, 0}, {:immediate, [0, 1]}, {:immediate, 1}, {:immediate, 1}},
              {:POP, {:var, 2}},
              {:SWITCH_V2, {:var, 2}, {:immediate, 2}, {:immediate, 3}}
            ]
          }},
       <<20, 55, 180, 56>> =>
         {[],
          {[],
           {:tuple,
            [
              :string,
              :string,
              {:variant, [tuple: [], tuple: [:string]]},
              {:variant, [tuple: [], tuple: [], tuple: [], tuple: []]}
            ]}},
          %{
            0 => [
              {:PUSH, {:var, -2}},
              {:PUSH, {:var, -3}},
              {:PUSH, {:var, -4}},
              {:PUSH, {:var, -5}},
              {:TUPLE, {:stack, 0}, {:immediate, 4}},
              :RETURN
            ]
          }},
       <<39, 89, 45, 234>> =>
         {[], {[:integer], {:variant, [tuple: [], tuple: [:address]]}},
          %{
            0 => [
              {:STORE, {:var, 0}, {:var, -8}},
              {:MAP_MEMBER, {:stack, 0}, {:var, -8}, {:arg, 0}},
              {:JUMPIF, {:stack, 0}, {:immediate, 2}}
            ],
            1 => [RETURNR: {:immediate, {:variant, [0, 1], 0, {}}}],
            2 => [
              {:MAP_LOOKUP, {:stack, 0}, {:var, 0}, {:arg, 0}},
              {:VARIANT, {:stack, 0}, {:immediate, [0, 1]}, {:immediate, 1}, {:immediate, 1}},
              :RETURN
            ]
          }},
       <<68, 214, 68, 31>> =>
         {[],
          {[
             :string,
             :string,
             {:variant, [tuple: [], tuple: [], tuple: [], tuple: []]},
             {:variant, [tuple: [], tuple: [:string]]}
           ], {:tuple, []}},
          %{
            0 => [
              PUSH: {:immediate, 1},
              PUSH: {:arg, 0},
              CALL: {:immediate, <<170, 192, 194, 134>>}
            ],
            1 => [
              {:EGT, {:stack, 0}, {:stack, 0}, {:stack, 0}},
              {:JUMPIF, {:stack, 0}, {:immediate, 3}}
            ],
            2 => [ABORT: {:immediate, "STRING_TOO_SHORT_NAME"}],
            3 => [
              PUSH: {:immediate, 1},
              PUSH: {:arg, 1},
              CALL: {:immediate, <<170, 192, 194, 134>>}
            ],
            4 => [
              {:EGT, {:stack, 0}, {:stack, 0}, {:stack, 0}},
              {:JUMPIF, {:stack, 0}, {:immediate, 6}}
            ],
            5 => [ABORT: {:immediate, "STRING_TOO_SHORT_SYMBOL"}],
            6 => [
              {:CALLER, {:var, -1}},
              {:STORE, {:var, -6}, {:immediate, %{}}},
              {:STORE, {:var, -7}, {:immediate, %{}}},
              {:STORE, {:var, -8}, {:immediate, %{}}},
              {:STORE, {:var, -9}, {:immediate, %{}}},
              {:STORE, {:var, -10}, {:immediate, %{}}},
              {:STORE, {:var, -2}, {:arg, 0}},
              {:STORE, {:var, -3}, {:arg, 1}},
              {:STORE, {:var, -4}, {:arg, 3}},
              {:STORE, {:var, -5}, {:arg, 2}},
              {:STORE, {:var, -11}, {:immediate, false}},
              {:RETURNR, {:immediate, {:tuple, {}}}}
            ]
          }},
       <<80, 90, 158, 181>> =>
         {[:private],
          {[:address, :address, :integer, {:variant, [tuple: [], tuple: [:string]]}],
           {:tuple, [:boolean, :boolean]}},
          %{
            0 => [
              {:IS_CONTRACT, {:stack, 0}, {:arg, 1}},
              {:JUMPIF, {:stack, 0}, {:immediate, 2}}
            ],
            1 => [RETURNR: {:immediate, {:tuple, {false, false}}}],
            2 => [
              {:PUSH, {:arg, 3}},
              {:PUSH, {:arg, 2}},
              {:PUSH, {:arg, 1}},
              {:PUSH, {:arg, 0}},
              {:GAS, {:stack, 0}},
              {:PUSH, {:immediate, 0}},
              {:ADDRESS_TO_CONTRACT, {:stack, 0}, {:arg, 1}},
              {:CALL_PGR, {:stack, 0}, {:immediate, <<145, 178, 164, 152>>},
               {:immediate,
                {:typerep,
                 {:tuple,
                  [
                    :address,
                    :address,
                    :integer,
                    {:variant, [tuple: [], tuple: [:string]]}
                  ]}}}, {:immediate, {:typerep, :boolean}}, {:stack, 0}, {:stack, 0},
               {:immediate, true}}
            ],
            3 => [
              {:POP, {:var, 2}},
              {:SWITCH_V2, {:var, 2}, {:immediate, 4}, {:immediate, 5}}
            ],
            4 => [RETURNR: {:immediate, {:tuple, {true, false}}}],
            5 => [
              {:PUSH, {:immediate, true}},
              {:VARIANT_ELEMENT, {:stack, 0}, {:var, 2}, {:immediate, 0}},
              {:TUPLE, {:stack, 0}, {:immediate, 2}},
              :RETURN
            ]
          }},
       <<99, 80, 161, 92>> =>
         {[],
          {[:address, {:variant, [tuple: [:string], tuple: [:string, :string]]}], {:tuple, []}},
          %{
            0 => [
              {:EQ, {:stack, 0}, {:var, -11}, {:immediate, false}},
              {:JUMPIF, {:stack, 0}, {:immediate, 2}}
            ],
            1 => [ABORT: {:immediate, "TOKEN_ALREADY_DEFINED"}],
            2 => [CALL: {:immediate, <<15, 27, 134, 79>>}],
            3 => [
              {:POP, {:var, 9999}},
              {:MAP_LOOKUPD, {:var, 15}, {:var, -7}, {:arg, 0}, {:immediate, 0}},
              {:ADD, {:stack, 0}, {:var, 15}, {:immediate, 1}},
              {:MAP_UPDATE, {:var, -7}, {:var, -7}, {:arg, 0}, {:stack, 0}},
              {:MAP_UPDATE, {:var, -6}, {:var, -6}, {:immediate, 0}, {:arg, 0}},
              {:MAP_UPDATE, {:var, -10}, {:var, -10}, {:immediate, 0}, {:arg, 1}},
              {:STORE, {:var, -11}, {:immediate, true}},
              {:PUSH, {:immediate, {:variant, [0, 1], 0, {}}}},
              {:PUSH, {:immediate, 0}},
              {:PUSH, {:arg, 0}},
              {:ADDRESS, {:stack, 0}},
              {:CALL, {:immediate, <<80, 90, 158, 181>>}}
            ],
            4 => [
              {:POP, {:var, 29}},
              {:ELEMENT, {:var, 30}, {:immediate, 0}, {:var, 29}},
              {:ELEMENT, {:var, 31}, {:immediate, 1}, {:var, 29}},
              {:JUMPIF, {:var, 30}, {:immediate, 7}}
            ],
            5 => [JUMP: {:immediate, 6}],
            6 => [
              {:ADDRESS, {:stack, 0}},
              {:PUSH, {:arg, 0}},
              {:PUSH, {:immediate, 0}},
              {:VARIANT, {:stack, 0}, {:immediate, [3, 4, 3]}, {:immediate, 0}, {:immediate, 3}},
              {:CALL_T, {:immediate, <<101, 165, 224, 15>>}}
            ],
            7 => [{:JUMPIF, {:var, 31}, {:immediate, 6}}],
            8 => [ABORT: {:immediate, "SAFE_MINT_FAILED"}]
          }},
       <<99, 148, 233, 122>> =>
         {[],
          {[:integer],
           {:variant,
            [
              tuple: [],
              tuple: [variant: [tuple: [:string], tuple: [:string, :string]]]
            ]}},
          %{
            0 => [
              {:INT_TO_STR, {:stack, 0}, {:arg, 0}},
              {:PUSH, {:immediate, "some-url"}},
              {:VARIANT, {:stack, 0}, {:immediate, [1, 2]}, {:immediate, 1}, {:immediate, 2}},
              {:VARIANT, {:stack, 0}, {:immediate, [0, 1]}, {:immediate, 1}, {:immediate, 1}},
              :RETURN
            ]
          }},
       <<101, 165, 224, 15>> =>
         {[:private],
          {[
             variant: [
               tuple: [:address, :address, :integer],
               tuple: [:address, :address, :integer, :string],
               tuple: [:address, :address, :string]
             ]
           ], {:tuple, []}},
          %{
            0 => [
              {:SWITCH_V3, {:arg, 0}, {:immediate, 1}, {:immediate, 2}, {:immediate, 3}}
            ],
            1 => [
              {:VARIANT_ELEMENT, {:var, 0}, {:arg, 0}, {:immediate, 0}},
              {:VARIANT_ELEMENT, {:var, 1}, {:arg, 0}, {:immediate, 1}},
              {:VARIANT_ELEMENT, {:var, 2}, {:arg, 0}, {:immediate, 2}},
              {:LOG4, {:immediate, ""},
               {:immediate,
                {:bytes,
                 <<34, 60, 57, 226, 157, 255, 100, 103, 254, 221, 160, 151, 88, 217, 23, 129, 197,
                   55, 46, 9, 31, 248, 107, 58, 249, 227, 16, 227, 134, 86, 43, 239>>}},
               {:var, 0}, {:var, 1}, {:var, 2}},
              {:RETURNR, {:immediate, {:tuple, {}}}}
            ],
            2 => [
              {:VARIANT_ELEMENT, {:var, 0}, {:arg, 0}, {:immediate, 0}},
              {:VARIANT_ELEMENT, {:var, 1}, {:arg, 0}, {:immediate, 1}},
              {:VARIANT_ELEMENT, {:var, 2}, {:arg, 0}, {:immediate, 2}},
              {:VARIANT_ELEMENT, {:var, 3}, {:arg, 0}, {:immediate, 3}},
              {:LOG4, {:var, 3},
               {:immediate,
                {:bytes,
                 <<217, 134, 199, 174, 182, 35, 122, 0, 47, 198, 63, 243, 175, 240, 113, 48, 118,
                   12, 83, 92, 166, 189, 207, 252, 14, 15, 209, 191, 45, 34, 92, 218>>}},
               {:var, 0}, {:var, 1}, {:var, 2}},
              {:RETURNR, {:immediate, {:tuple, {}}}}
            ],
            3 => [
              {:VARIANT_ELEMENT, {:var, 0}, {:arg, 0}, {:immediate, 0}},
              {:VARIANT_ELEMENT, {:var, 1}, {:arg, 0}, {:immediate, 1}},
              {:VARIANT_ELEMENT, {:var, 2}, {:arg, 0}, {:immediate, 2}},
              {:LOG3, {:var, 2},
               {:immediate,
                {:bytes,
                 <<108, 111, 71, 26, 61, 180, 206, 14, 183, 131, 70, 177, 193, 62, 152, 222, 97,
                   20, 182, 70, 187, 17, 93, 182, 53, 129, 148, 151, 124, 100, 218, 139>>}},
               {:var, 0}, {:var, 1}},
              {:RETURNR, {:immediate, {:tuple, {}}}}
            ]
          }},
       <<102, 66, 227, 51>> =>
         {[], {[:integer, :address], :boolean},
          %{
            0 => [
              {:STORE, {:var, 0}, {:var, -8}},
              {:MAP_MEMBER, {:stack, 0}, {:var, -8}, {:arg, 0}},
              {:JUMPIF, {:stack, 0}, {:immediate, 4}}
            ],
            1 => [
              {:PUSH, {:immediate, {:variant, [0, 1], 0, {}}}},
              {:POP, {:var, 2}},
              {:SWITCH_V2, {:var, 2}, {:immediate, 2}, {:immediate, 3}}
            ],
            2 => [RETURNR: {:immediate, false}],
            3 => [
              {:VARIANT_ELEMENT, {:var, 3}, {:var, 2}, {:immediate, 0}},
              {:EQ, {:stack, 0}, {:var, 3}, {:arg, 1}},
              :RETURN
            ],
            4 => [
              {:MAP_LOOKUP, {:stack, 0}, {:var, 0}, {:arg, 0}},
              {:VARIANT, {:stack, 0}, {:immediate, [0, 1]}, {:immediate, 1}, {:immediate, 1}},
              {:POP, {:var, 2}},
              {:SWITCH_V2, {:var, 2}, {:immediate, 2}, {:immediate, 3}}
            ]
          }},
       <<104, 18, 102, 160>> =>
         {[], {[:address, :integer, :boolean], {:tuple, []}},
          %{
            0 => [PUSH: {:arg, 1}, CALL: {:immediate, <<252, 217, 167, 216>>}],
            1 => [{:POP, {:var, 9999}}, {:JUMPIF, {:arg, 2}, {:immediate, 6}}],
            2 => [PUSH: {:arg, 1}, CALL: {:immediate, <<189, 73, 253, 99>>}],
            3 => [JUMP: {:immediate, 4}],
            4 => [
              {:POP, {:var, 9999}},
              {:STORE, {:var, 2}, {:var, -6}},
              {:MAP_LOOKUP, {:stack, 0}, {:var, 2}, {:arg, 1}},
              {:PUSH, {:arg, 0}},
              {:PUSH, {:arg, 1}},
              {:PUSH, {:arg, 2}},
              {:CALL, {:immediate, <<4, 167, 206, 191>>}}
            ],
            5 => [
              {:VARIANT, {:stack, 0}, {:immediate, [3, 4, 3]}, {:immediate, 1}, {:immediate, 4}},
              {:CALL_T, {:immediate, <<101, 165, 224, 15>>}}
            ],
            6 => [
              {:MAP_UPDATE, {:var, -8}, {:var, -8}, {:arg, 1}, {:arg, 0}},
              {:PUSH, {:immediate, {:tuple, {}}}},
              {:JUMP, {:immediate, 4}}
            ]
          }},
       <<112, 189, 49, 130>> =>
         {[:private], {[:integer, :address], {:tuple, []}},
          %{
            0 => [
              PUSH: {:arg, 1},
              PUSH: {:arg, 0},
              CALL: {:immediate, <<180, 143, 200, 18>>}
            ],
            1 => [{:JUMPIF, {:stack, 0}, {:immediate, 3}}],
            2 => [ABORT: {:immediate, "ONLY_OWNER_CALL_ALLOWED"}],
            3 => [RETURNR: {:immediate, {:tuple, {}}}]
          }},
       <<132, 161, 93, 161>> =>
         {[],
          {[:address, :address, :integer, {:variant, [tuple: [], tuple: [:string]]}],
           {:tuple, []}},
          %{
            0 => [PUSH: {:arg, 2}, CALL: {:immediate, <<252, 217, 167, 216>>}],
            1 => [
              POP: {:var, 9999},
              PUSH: {:arg, 0},
              PUSH: {:arg, 2},
              CALL: {:immediate, <<112, 189, 49, 130>>}
            ],
            2 => [
              POP: {:var, 9999},
              PUSH: {:arg, 2},
              CALL: {:immediate, <<189, 73, 253, 99>>}
            ],
            3 => [
              {:POP, {:var, 9999}},
              {:STORE, {:var, 9}, {:var, -7}},
              {:MAP_LOOKUP, {:var, 14}, {:var, 9}, {:arg, 0}},
              {:MAP_LOOKUPD, {:var, 15}, {:var, 9}, {:arg, 1}, {:immediate, 0}},
              {:SUB, {:stack, 0}, {:var, 14}, {:immediate, 1}},
              {:ADD, {:stack, 0}, {:var, 15}, {:immediate, 1}},
              {:MAP_UPDATE, {:stack, 0}, {:var, 9}, {:arg, 1}, {:stack, 0}},
              {:MAP_UPDATE, {:var, -7}, {:stack, 0}, {:arg, 0}, {:stack, 0}},
              {:MAP_UPDATE, {:var, -6}, {:var, -6}, {:arg, 2}, {:arg, 1}},
              {:PUSH, {:arg, 3}},
              {:PUSH, {:arg, 2}},
              {:PUSH, {:arg, 1}},
              {:PUSH, {:arg, 0}},
              {:CALL, {:immediate, <<80, 90, 158, 181>>}}
            ],
            4 => [
              {:POP, {:var, 29}},
              {:ELEMENT, {:var, 30}, {:immediate, 0}, {:var, 29}},
              {:ELEMENT, {:var, 31}, {:immediate, 1}, {:var, 29}},
              {:JUMPIF, {:var, 30}, {:immediate, 7}}
            ],
            5 => [JUMP: {:immediate, 6}],
            6 => [
              {:PUSH, {:arg, 0}},
              {:PUSH, {:arg, 1}},
              {:PUSH, {:arg, 2}},
              {:VARIANT, {:stack, 0}, {:immediate, [3, 4, 3]}, {:immediate, 0}, {:immediate, 3}},
              {:CALL_T, {:immediate, <<101, 165, 224, 15>>}}
            ],
            7 => [{:JUMPIF, {:var, 31}, {:immediate, 6}}],
            8 => [ABORT: {:immediate, "SAFE_TRANSFER_FAILED"}]
          }},
       <<162, 103, 192, 75>> =>
         {[], {[:address, :boolean], {:tuple, []}},
          %{
            0 => [
              {:STORE, {:var, 10}, {:immediate, %{}}},
              {:STORE, {:var, 11}, {:immediate, %{}}},
              {:MAP_UPDATE, {:stack, 0}, {:var, 11}, {:arg, 0}, {:arg, 1}},
              {:CALLER, {:stack, 0}},
              {:MAP_UPDATE, {:var, -9}, {:var, 10}, {:stack, 0}, {:stack, 0}},
              {:CALLER, {:stack, 0}},
              {:PUSH, {:arg, 0}},
              {:PUSH, {:arg, 1}},
              {:CALL, {:immediate, <<4, 167, 206, 191>>}}
            ],
            1 => [
              {:VARIANT, {:stack, 0}, {:immediate, [3, 4, 3]}, {:immediate, 2}, {:immediate, 3}},
              {:CALL_T, {:immediate, <<101, 165, 224, 15>>}}
            ]
          }},
       <<170, 192, 194, 134>> =>
         {[:private], {[:string], :integer},
          %{0 => [{:STR_LENGTH, {:stack, 0}, {:arg, 0}}, :RETURN]}},
       <<180, 140, 22, 132>> =>
         {[], {[:address], {:variant, [tuple: [], tuple: [:integer]]}},
          %{
            0 => [
              {:STORE, {:var, 0}, {:var, -7}},
              {:MAP_MEMBER, {:stack, 0}, {:var, -7}, {:arg, 0}},
              {:JUMPIF, {:stack, 0}, {:immediate, 2}}
            ],
            1 => [RETURNR: {:immediate, {:variant, [0, 1], 0, {}}}],
            2 => [
              {:MAP_LOOKUP, {:stack, 0}, {:var, 0}, {:arg, 0}},
              {:VARIANT, {:stack, 0}, {:immediate, [0, 1]}, {:immediate, 1}, {:immediate, 1}},
              :RETURN
            ]
          }},
       <<180, 143, 200, 18>> =>
         {[:private], {[:integer, :address], :boolean},
          %{
            0 => [
              {:STORE, {:var, 0}, {:var, -6}},
              {:MAP_MEMBER, {:stack, 0}, {:var, -6}, {:arg, 0}},
              {:JUMPIF, {:stack, 0}, {:immediate, 4}}
            ],
            1 => [
              {:PUSH, {:immediate, {:variant, [0, 1], 0, {}}}},
              {:POP, {:var, 2}},
              {:SWITCH_V2, {:var, 2}, {:immediate, 2}, {:immediate, 3}}
            ],
            2 => [RETURNR: {:immediate, false}],
            3 => [
              {:VARIANT_ELEMENT, {:var, 3}, {:var, 2}, {:immediate, 0}},
              {:EQ, {:stack, 0}, {:var, 3}, {:arg, 1}},
              :RETURN
            ],
            4 => [
              {:MAP_LOOKUP, {:stack, 0}, {:var, 0}, {:arg, 0}},
              {:VARIANT, {:stack, 0}, {:immediate, [0, 1]}, {:immediate, 1}, {:immediate, 1}},
              {:POP, {:var, 2}},
              {:SWITCH_V2, {:var, 2}, {:immediate, 2}, {:immediate, 3}}
            ]
          }},
       <<189, 73, 253, 99>> =>
         {[:private], {[:integer], {:tuple, []}},
          %{
            0 => [
              {:MAP_MEMBER, {:stack, 0}, {:var, -8}, {:arg, 0}},
              {:JUMPIF, {:stack, 0}, {:immediate, 2}}
            ],
            1 => [RETURNR: {:immediate, {:tuple, {}}}],
            2 => [
              {:MAP_DELETE, {:var, -8}, {:var, -8}, {:arg, 0}},
              {:RETURNR, {:immediate, {:tuple, {}}}}
            ]
          }},
       <<222, 10, 63, 194>> => {[], {[], {:list, :string}}, %{0 => [RETURNR: {:immediate, []}]}},
       <<252, 217, 167, 216>> =>
         {[:private], {[:integer], {:tuple, []}},
          %{
            0 => [PUSH: {:arg, 0}, CALL: {:immediate, <<254, 174, 164, 250>>}],
            1 => [
              {:POP, {:var, 0}},
              {:SWITCH_V2, {:var, 0}, {:immediate, 12}, {:immediate, 2}}
            ],
            2 => [
              {:VARIANT_ELEMENT, {:var, 1}, {:var, 0}, {:immediate, 0}},
              {:CALLER, {:stack, 0}},
              {:EQ, {:stack, 0}, {:stack, 0}, {:var, 1}},
              {:JUMPIF, {:stack, 0}, {:immediate, 11}}
            ],
            3 => [
              CALLER: {:stack, 0},
              PUSH: {:arg, 0},
              CALL: {:immediate, <<102, 66, 227, 51>>}
            ],
            4 => [{:JUMPIF, {:stack, 0}, {:immediate, 9}}],
            5 => [
              CALLER: {:stack, 0},
              PUSH: {:var, 1},
              CALL: {:immediate, <<15, 89, 34, 233>>}
            ],
            6 => [JUMP: {:immediate, 7}],
            7 => [{:JUMPIF, {:stack, 0}, {:immediate, 10}}],
            8 => [
              ABORT: {:immediate, "ONLY_OWNER_APPROVED_OR_OPERATOR_CALL_ALLOWED"}
            ],
            9 => [PUSH: {:immediate, true}, JUMP: {:immediate, 7}],
            10 => [RETURNR: {:immediate, {:tuple, {}}}],
            11 => [PUSH: {:immediate, true}, JUMP: {:immediate, 7}],
            12 => [ABORT: {:immediate, "INVALID_TOKEN_ID"}]
          }},
       <<254, 174, 164, 250>> =>
         {[], {[:integer], {:variant, [tuple: [], tuple: [:address]]}},
          %{
            0 => [
              {:STORE, {:var, 0}, {:var, -6}},
              {:MAP_MEMBER, {:stack, 0}, {:var, -6}, {:arg, 0}},
              {:JUMPIF, {:stack, 0}, {:immediate, 2}}
            ],
            1 => [RETURNR: {:immediate, {:variant, [0, 1], 0, {}}}],
            2 => [
              {:MAP_LOOKUP, {:stack, 0}, {:var, 0}, {:arg, 0}},
              {:VARIANT, {:stack, 0}, {:immediate, [0, 1]}, {:immediate, 1}, {:immediate, 1}},
              :RETURN
            ]
          }}
     },
     %{
       <<4, 167, 206, 191>> => ".Utils.bool_to_string",
       <<15, 27, 134, 79>> => ".BaseNFT.require_contract_owner",
       <<15, 89, 34, 233>> => "is_approved_for_all",
       <<20, 55, 180, 56>> => "meta_info",
       <<39, 89, 45, 234>> => "get_approved",
       <<68, 214, 68, 31>> => "init",
       <<80, 90, 158, 181>> => ".BaseNFT.invoke_nft_receiver",
       <<99, 80, 161, 92>> => "define_token",
       <<99, 148, 233, 122>> => "metadata",
       <<101, 165, 224, 15>> => "Chain.event",
       <<102, 66, 227, 51>> => "is_approved",
       <<104, 18, 102, 160>> => "approve",
       <<112, 189, 49, 130>> => ".BaseNFT.require_token_owner",
       <<132, 161, 93, 161>> => "transfer",
       <<162, 103, 192, 75>> => "approve_all",
       <<170, 192, 194, 134>> => ".String.length",
       <<180, 140, 22, 132>> => "balance",
       <<180, 143, 200, 18>> => ".BaseNFT.is_token_owner",
       <<189, 73, 253, 99>> => ".BaseNFT.remove_approval",
       <<222, 10, 63, 194>> => "aex141_extensions",
       <<252, 217, 167, 216>> => ".BaseNFT.require_authorized",
       <<254, 174, 164, 250>> => "owner"
     }, %{}}
  end
end

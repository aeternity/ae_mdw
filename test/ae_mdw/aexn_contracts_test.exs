defmodule AeMdw.AexnContractsTest do
  use ExUnit.Case

  alias AeMdw.AexnContracts

  import Mock

  @wrong_burn {[], {[:integer], :boolean}, %{}}
  @wrong_mint {[], {[:address, :string, {:variant, [tuple: [], tuple: [:string]]}], :integer},
               %{}}

  describe "is_aex141?/1" do
    test "returns true for a mintable" do
      contract_pk = :crypto.strong_rand_bytes(32)
      type_info = unique_nfts_contract_fcode(without_burn: true)
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "aex141_extensions", [] ->
             {:ok, ["mintable"]}
           end
         ]}
      ] do
        assert AexnContracts.is_aex141?(contract_pk)
      end
    end

    test "returns true for a mintable and burnable" do
      contract_pk = :crypto.strong_rand_bytes(32)
      type_info = unique_nfts_contract_fcode()
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "aex141_extensions", [] ->
             {:ok, ["mintable", "burnable"]}
           end
         ]}
      ] do
        assert AexnContracts.is_aex141?(contract_pk)
      end
    end

    test "returns false for different mintable" do
      contract_pk = :crypto.strong_rand_bytes(32)
      type_info = unique_nfts_contract_fcode(wrong_mint: true)
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "aex141_extensions", [] ->
             {:ok, ["mintable", "burnable"]}
           end
         ]}
      ] do
        refute AexnContracts.is_aex141?(contract_pk)
      end
    end

    test "returns false for different burnable" do
      contract_pk = :crypto.strong_rand_bytes(32)
      type_info = unique_nfts_contract_fcode(wrong_burn: true)
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "aex141_extensions", [] ->
             {:ok, ["mintable", "burnable"]}
           end
         ]}
      ] do
        refute AexnContracts.is_aex141?(contract_pk)
      end
    end
  end

  defp unique_nfts_contract_fcode(opts \\ []) do
    remove_burn = Keyword.get(opts, :without_burn, false)
    remove_mint = Keyword.get(opts, :without_mint, false)
    wrong_burn = Keyword.get(opts, :wrong_burn, false)
    wrong_mint = Keyword.get(opts, :wrong_mint, false)

    functions = %{
      <<4, 167, 206, 191>> => {[:private], {[:boolean], :string}, %{}},
      <<15, 89, 34, 233>> => {[], {[:address, :address], :boolean}, %{}},
      <<20, 55, 180, 56>> =>
        {[],
         {[],
          {:tuple,
           [
             :string,
             :string,
             {:variant, [tuple: [], tuple: [:string]]},
             {:variant, [tuple: [], tuple: [], tuple: []]}
           ]}}, %{}},
      <<39, 89, 45, 234>> => {[], {[:integer], {:variant, [tuple: [], tuple: [:address]]}}, %{}},
      <<54, 189, 143, 3>> => {[:private], {[], {:map, {:tvar, 0}, {:tuple, []}}}, %{}},
      <<66, 213, 125, 105>> => {[:private], {[], {:tuple, []}}, %{}},
      <<68, 214, 68, 31>> => {[], {[:string, :string], {:tuple, []}}, %{}},
      <<72, 150, 48, 41>> => {[:private], {[:integer], :address}, %{}},
      <<99, 148, 233, 122>> =>
        {[],
         {[:integer],
          {:variant,
           [
             tuple: [],
             tuple: [variant: [tuple: [:string], tuple: [{:map, :string, :string}]]]
           ]}}, %{}},
      <<101, 165, 224, 15>> =>
        {[:private],
         {[
            variant: [
              tuple: [:address, :integer],
              tuple: [:address, :address, :integer],
              tuple: [:address, :address, :integer, :string],
              tuple: [:address, :address, :string],
              tuple: [:address, :integer]
            ]
          ], {:tuple, []}}, %{}},
      <<102, 66, 227, 51>> => {[], {[:integer, :address], :boolean}, %{}},
      <<104, 18, 102, 160>> => {[], {[:address, :integer, :boolean], {:tuple, []}}, %{}},
      <<116, 218, 90, 49>> =>
        {[:private],
         {[{:tvar, 0}, {:map, {:tvar, 0}, {:tuple, []}}], {:map, {:tvar, 0}, {:tuple, []}}}, %{}},
      <<132, 161, 93, 161>> =>
        {[], {[:address, :integer, {:variant, [tuple: [], tuple: [:string]]}], {:tuple, []}}, %{}},
      <<146, 113, 210, 58>> => {[:private], {[:integer], {:tuple, []}}, %{}},
      <<160, 2, 139, 120>> =>
        {[:private], {[tuple: [:string, :any], list: {:tvar, 0}], {:list, {:tvar, 1}}}, %{}},
      <<160, 55, 105, 6>> =>
        {[:private], {[{:map, {:tvar, 0}, {:tuple, []}}], {:list, {:tvar, 0}}}, %{}},
      <<162, 103, 192, 75>> => {[], {[:address, :boolean], {:tuple, []}}, %{}},
      <<170, 192, 194, 134>> => {[:private], {[:string], :integer}, %{}},
      <<177, 239, 193, 123>> => {[], {[:integer], {:tuple, []}}, %{}},
      <<180, 140, 22, 132>> =>
        {[], {[:address], {:variant, [tuple: [], tuple: [:integer]]}}, %{}},
      <<184, 120, 21, 14>> =>
        {[:private],
         {[:address, :integer, {:variant, [tuple: [], tuple: [:string]]}],
          {:tuple, [:boolean, :boolean]}}, %{}},
      <<207, 221, 154, 162>> =>
        {[],
         {[
            :address,
            {:variant,
             [
               tuple: [],
               tuple: [variant: [tuple: [:string], tuple: [{:map, :string, :string}]]]
             ]},
            {:variant, [tuple: [], tuple: [:string]]}
          ], :integer}, %{}},
      <<208, 195, 108, 184>> =>
        {[:private],
         {[{:tvar, 0}, {:map, {:tvar, 0}, {:tuple, []}}], {:map, {:tvar, 0}, {:tuple, []}}}, %{}},
      <<219, 99, 117, 168>> => {[], {[], :integer}, %{}},
      <<222, 10, 63, 194>> => {[], {[], {:list, :string}}, %{}},
      <<227, 243, 60, 8>> => {[:private], {[tuple: [tvar: 0, tvar: 1]], {:tvar, 0}}, %{}},
      <<234, 175, 198, 221>> => {[], {[:address], {:list, :integer}}, %{}},
      <<254, 174, 164, 250>> =>
        {[], {[:integer], {:variant, [tuple: [], tuple: [:address]]}}, %{}},
      <<255, 232, 237, 108>> => {[:private], {[:any, :any], :any}, %{}}
    }

    hash_names = %{
      <<4, 167, 206, 191>> => ".Utils.bool_to_string",
      <<15, 89, 34, 233>> => "is_approved_for_all",
      <<20, 55, 180, 56>> => "meta_info",
      <<39, 89, 45, 234>> => "get_approved",
      <<54, 189, 143, 3>> => ".Set.new",
      <<66, 213, 125, 105>> => ".CollectionUniqueNFTs.require_contract_owner",
      <<68, 214, 68, 31>> => "init",
      <<72, 150, 48, 41>> => ".CollectionUniqueNFTs.require_authorized",
      <<99, 148, 233, 122>> => "metadata",
      <<101, 165, 224, 15>> => "Chain.event",
      <<102, 66, 227, 51>> => "is_approved",
      <<104, 18, 102, 160>> => "approve",
      <<116, 218, 90, 49>> => ".Set.delete",
      <<132, 161, 93, 161>> => "transfer",
      <<146, 113, 210, 58>> => ".CollectionUniqueNFTs.remove_approval",
      <<160, 2, 139, 120>> => ".List.map",
      <<160, 55, 105, 6>> => ".Set.to_list",
      <<162, 103, 192, 75>> => "approve_all",
      <<170, 192, 194, 134>> => ".String.length",
      <<177, 239, 193, 123>> => "burn",
      <<180, 140, 22, 132>> => "balance",
      <<184, 120, 21, 14>> => ".CollectionUniqueNFTs.invoke_nft_receiver",
      <<207, 221, 154, 162>> => "mint",
      <<208, 195, 108, 184>> => ".Set.insert",
      <<219, 99, 117, 168>> => "total_supply",
      <<222, 10, 63, 194>> => "aex141_extensions",
      <<227, 243, 60, 8>> => ".Pair.fst",
      <<234, 175, 198, 221>> => "get_owned_tokens",
      <<254, 174, 164, 250>> => "owner",
      <<255, 232, 237, 108>> => ".^2793"
    }

    functions =
      cond do
        remove_burn -> Map.delete(functions, <<177, 239, 193, 123>>)
        wrong_burn -> Map.put(functions, <<177, 239, 193, 123>>, @wrong_burn)
        true -> functions
      end

    functions =
      cond do
        remove_mint -> Map.delete(functions, <<207, 221, 154, 162>>)
        wrong_mint -> Map.put(functions, <<207, 221, 154, 162>>, @wrong_mint)
        true -> functions
      end

    {:fcode, functions, hash_names, %{}}
  end
end

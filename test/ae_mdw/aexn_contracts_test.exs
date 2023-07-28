defmodule AeMdw.AexnContractsTest do
  use ExUnit.Case

  alias AeMdw.AexnContracts

  import Mock

  @wrong_burn {[], {[:integer], :boolean}, %{}}
  @wrong_mint {[], {[:address, :string, {:variant, [tuple: [], tuple: [:string]]}], :integer},
               %{}}

  describe "call_meta_info/2" do
    test "succeeds with regular aex9 meta_info" do
      contract_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "meta_info", [] ->
             meta_info_tuple = {"name", "SYMBOL", 18}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYMBOL", 18}} = AexnContracts.call_meta_info(:aex9, contract_pk)
      end
    end

    test "succeeds with rearranged aex9 meta_info 1" do
      contract_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "meta_info", [] ->
             meta_info_tuple = {"Abc", 18, "ABC"}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"Abc", "ABC", 18}} = AexnContracts.call_meta_info(:aex9, contract_pk)
      end
    end

    test "succeeds with rearranged aex9 meta_info 2" do
      contract_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "meta_info", [] ->
             meta_info_tuple = {"ABC", "Abc", 18}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"Abc", "ABC", 18}} = AexnContracts.call_meta_info(:aex9, contract_pk)
      end
    end

    test "succeeds with rearranged aex9 meta_info 3" do
      contract_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "meta_info", [] ->
             meta_info_tuple = {"ABC", 18, "Abc"}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"Abc", "ABC", 18}} = AexnContracts.call_meta_info(:aex9, contract_pk)
      end
    end

    test "succeeds with rearranged aex9 meta_info 4" do
      contract_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "meta_info", [] ->
             meta_info_tuple = {18, "Abc", "ABC"}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"Abc", "ABC", 18}} = AexnContracts.call_meta_info(:aex9, contract_pk)
      end
    end

    test "succeeds with rearranged aex9 meta_info 5" do
      contract_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "meta_info", [] ->
             meta_info_tuple = {18, "ABC", "Abc"}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"Abc", "ABC", 18}} = AexnContracts.call_meta_info(:aex9, contract_pk)
      end
    end

    test "succeeds with meta info from previous nft draft (hackaton)" do
      contract_pk = :crypto.strong_rand_bytes(32)
      base_url = "https://some-base-url.com"

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "meta_info", [] ->
             variant_url = {:variant, [0, 1], 1, base_url}
             variant_type = {:variant, [0, 0, 0, 0], 0, {}}
             meta_info_tuple = {"name", "SYMBOL", variant_url, variant_type}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYMBOL", ^base_url, :url}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk)
      end
    end

    test "succeeds with nft standard meta info without base url" do
      contract_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "meta_info", [] ->
             variant_url = {:variant, [0, 1], 0, {}}
             variant_type = {:variant, [0, 0, 0], 2, {}}
             meta_info_tuple = {"name", "SYMBOL", variant_url, variant_type}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYMBOL", nil, :map}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk)
      end
    end

    test "succeeds with nft standard meta info with base url" do
      contract_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "meta_info", [] ->
             variant_url = {:variant, [0, 1], 1, "http://baseurl"}
             variant_type = {:variant, [0, 0, 0], 2, {}}
             meta_info_tuple = {"name", "SYMBOL", variant_url, variant_type}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYMBOL", "http://baseurl", :map}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk)
      end
    end

    test "succeeds with nft rearranged meta info 1" do
      contract_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "meta_info", [] ->
             variant_url = {:variant, [0, 1], 0, ""}
             variant_type = {:variant, [0, 0, 0], 2, {}}
             meta_info_tuple = {"name", variant_url, "SYMBOL", variant_type}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYMBOL", nil, :map}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk)
      end
    end

    test "succeeds with nft rearranged meta info 2" do
      contract_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "meta_info", [] ->
             variant_url = {:variant, [0, 1], 0, ""}
             variant_type = {:variant, [0, 0, 0], 2, {}}
             meta_info_tuple = {"name", variant_url, variant_type, "SYMBOL"}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYMBOL", nil, :map}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk)
      end
    end

    test "succeeds with nft rearranged meta info 3" do
      contract_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "meta_info", [] ->
             variant_url = {:variant, [0, 1], 0, ""}
             variant_type = {:variant, [0, 0, 0], 2, {}}
             meta_info_tuple = {"SYMBOL", "name", variant_url, variant_type}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYMBOL", nil, :map}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk)
      end
    end

    test "succeeds with nft rearranged meta info 4" do
      contract_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "meta_info", [] ->
             variant_url = {:variant, [0, 1], 0, ""}
             variant_type = {:variant, [0, 0, 0], 2, {}}
             meta_info_tuple = {"SYMBOL", variant_url, variant_type, "name"}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYMBOL", nil, :map}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk)
      end
    end

    test "returns :unknown metadata type when does not comply to nft standard" do
      contract_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "meta_info", [] ->
             variant_url = {:variant, [0, 1], 0, ""}
             variant_type = {:variant, [0, 0], 0, {}}
             meta_info_tuple = {"name", "SYMBOL", variant_url, variant_type}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYMBOL", nil, :unknown}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk)
      end
    end

    test "returns format error values when tuple format is unexpected" do
      contract_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "meta_info", [] ->
             {:ok, {:tuple, {"name", "symbol"}}}
           end
         ]}
      ] do
        assert {:ok, {:format_error, :format_error, nil}} =
                 AexnContracts.call_meta_info(:aex9, contract_pk)
      end
    end

    test "returns out of gas error when call_contract fails" do
      contract_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "meta_info", [] ->
             {:error, :dry_run_error}
           end
         ]}
      ] do
        assert {:ok, {:out_of_gas_error, :out_of_gas_error, :out_of_gas_error, nil}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk)
      end
    end
  end

  describe "is_aex141?/1" do
    test "returns true for a immediate mintable" do
      contract_pk = :crypto.strong_rand_bytes(32)
      type_info = unique_nfts_contract_fcode(extensions: ["mintable"])
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      assert AexnContracts.is_aex141?(contract_pk)
    end

    test "returns true for immediate mintable and burnable" do
      contract_pk = :crypto.strong_rand_bytes(32)
      type_info = unique_nfts_contract_fcode(extensions: ["mintable", "burnable"])
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      assert AexnContracts.is_aex141?(contract_pk)
    end

    test "returns true for not immediate mintable" do
      contract_pk = :crypto.strong_rand_bytes(32)
      type_info = unique_nfts_contract_fcode(not_immediate: true)
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

    test "returns false for different not immediate mintable" do
      contract_pk = :crypto.strong_rand_bytes(32)
      type_info = unique_nfts_contract_fcode(wrong_mint: true, not_immediate: true)
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "aex141_extensions", [] ->
             {:ok, ["mintable"]}
           end
         ]}
      ] do
        refute AexnContracts.is_aex141?(contract_pk)
      end
    end

    test "returns false for different mintable" do
      contract_pk = :crypto.strong_rand_bytes(32)

      type_info =
        unique_nfts_contract_fcode(wrong_mint: true, extensions: ["mintable", "burnable"])

      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      refute AexnContracts.is_aex141?(contract_pk)
    end

    test "returns false for different burnable" do
      contract_pk = :crypto.strong_rand_bytes(32)

      type_info =
        unique_nfts_contract_fcode(wrong_burn: true, extensions: ["mintable", "burnable"])

      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      refute AexnContracts.is_aex141?(contract_pk)
    end
  end

  describe "has_aex141_signatures?/2" do
    test "returns true for new nft contracts" do
      contract_pk = :crypto.strong_rand_bytes(32)
      type_info = unique_nfts_contract_fcode()
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      assert AeMdw.Util.max_int() |> AexnContracts.has_aex141_signatures?(contract_pk)
    end

    test "returns true for previous base nft at previous spec" do
      contract_pk = :crypto.strong_rand_bytes(32)
      type_info = base_nft_fcode()
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      assert AexnContracts.has_aex141_signatures?(600_000, contract_pk)
    end

    test "returns false for incomplete previous base nft at previous spec" do
      contract_pk = :crypto.strong_rand_bytes(32)
      type_info = incomplete_base_nft_fcode()
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      refute AexnContracts.has_aex141_signatures?(600_000, contract_pk)
    end

    test "returns false for previous base nft" do
      contract_pk = :crypto.strong_rand_bytes(32)
      type_info = base_nft_fcode()
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      refute AeMdw.Util.max_int() |> AexnContracts.has_aex141_signatures?(contract_pk)
    end
  end

  defp unique_nfts_contract_fcode(opts \\ []) do
    wrong_burn = Keyword.get(opts, :wrong_burn, false)
    wrong_mint = Keyword.get(opts, :wrong_mint, false)
    not_immediate = Keyword.get(opts, :not_immediate, false)
    immediate_extensions = Keyword.get(opts, :extensions, [])

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
      if wrong_burn do
        Map.put(functions, <<177, 239, 193, 123>>, @wrong_burn)
      else
        functions
      end

    functions =
      if wrong_mint do
        Map.put(functions, <<207, 221, 154, 162>>, @wrong_mint)
      else
        functions
      end

    aex141_extensions_code =
      if not_immediate do
        %{0 => [CALL: {:immediate, <<1, 2, 3, 4>>}]}
      else
        %{0 => [RETURNR: {:immediate, immediate_extensions}]}
      end

    functions =
      Map.put(
        functions,
        <<222, 10, 63, 194>>,
        {[], {[], {:list, :string}}, aex141_extensions_code}
      )

    {:fcode, functions, hash_names, %{}}
  end

  defp incomplete_base_nft_fcode do
    {:fcode, functions, hash_names, %{}} = base_nft_fcode()

    {:fcode, Map.delete(functions, <<20, 55, 180, 56>>), hash_names, %{}}
  end

  defp base_nft_fcode do
    {:fcode,
     %{
       <<4, 167, 206, 191>> => {[:private], {[:boolean], :string}, %{}},
       <<15, 27, 134, 79>> => {[:private], {[], {:tuple, []}}, %{}},
       <<15, 89, 34, 233>> => {[], {[:address, :address], :boolean}, %{}},
       <<20, 55, 180, 56>> =>
         {[],
          {[],
           {:tuple,
            [
              :string,
              :string,
              {:variant, [tuple: [], tuple: [:string]]},
              {:variant, [tuple: [], tuple: [], tuple: [], tuple: []]}
            ]}}, %{}},
       <<32, 4, 164, 216>> => {[:private], {[list: :string], :string}, %{}},
       <<39, 89, 45, 234>> => {[], {[:integer], {:variant, [tuple: [], tuple: [:address]]}}, %{}},
       <<68, 214, 68, 31>> =>
         {[],
          {[
             :string,
             :string,
             {:variant, [tuple: [], tuple: [:string]]},
             {:variant, [tuple: [], tuple: [], tuple: [], tuple: []]}
           ], {:tuple, []}}, %{}},
       <<80, 90, 158, 181>> =>
         {[:private],
          {[:address, :address, :integer, {:variant, [tuple: [], tuple: [:string]]}],
           {:tuple, [:boolean, :boolean]}}, %{}},
       <<93, 142, 50, 216>> => {[:private], {[:any, :any, :any], :any}, %{}},
       <<94, 119, 225, 37>> =>
         {[:private], {[tuple: [:string, :any], tvar: 0, list: {:tvar, 1}], {:tvar, 0}}, %{}},
       <<99, 80, 161, 92>> =>
         {[],
          {[
             :address,
             {:variant, [tuple: [:string], tuple: [{:map, :string, :string}]]}
           ], {:tuple, []}}, %{}},
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
               tuple: [:address, :address, :integer],
               tuple: [:address, :address, :integer, :string],
               tuple: [:address, :address, :string]
             ]
           ], {:tuple, []}}, %{}},
       <<102, 66, 227, 51>> => {[], {[:integer, :address], :boolean}, %{}},
       <<104, 18, 102, 160>> => {[], {[:address, :integer, :boolean], {:tuple, []}}, %{}},
       <<112, 189, 49, 130>> => {[:private], {[:integer, :address], {:tuple, []}}, %{}},
       <<132, 161, 93, 161>> =>
         {[],
          {[:address, :address, :integer, {:variant, [tuple: [], tuple: [:string]]}],
           {:tuple, []}}, %{}},
       <<162, 103, 192, 75>> => {[], {[:address, :boolean], {:tuple, []}}, %{}},
       <<170, 192, 194, 134>> => {[:private], {[:string], :integer}, %{}},
       <<180, 140, 22, 132>> =>
         {[], {[:address], {:variant, [tuple: [], tuple: [:integer]]}}, %{}},
       <<180, 143, 200, 18>> => {[:private], {[:integer, :address], :boolean}, %{}},
       <<189, 73, 253, 99>> => {[:private], {[:integer], {:tuple, []}}, %{}},
       <<222, 10, 63, 194>> => {[], {[], {:list, :string}}, %{0 => [RETURNR: {:immediate, []}]}},
       <<252, 217, 167, 216>> => {[:private], {[:integer], {:tuple, []}}, %{}},
       <<254, 174, 164, 250>> =>
         {[], {[:integer], {:variant, [tuple: [], tuple: [:address]]}}, %{}}
     },
     %{
       <<4, 167, 206, 191>> => ".Utils.bool_to_string",
       <<15, 27, 134, 79>> => ".BaseNFT.require_contract_owner",
       <<15, 89, 34, 233>> => "is_approved_for_all",
       <<20, 55, 180, 56>> => "meta_info",
       <<32, 4, 164, 216>> => ".String.concats",
       <<39, 89, 45, 234>> => "get_approved",
       <<68, 214, 68, 31>> => "init",
       <<80, 90, 158, 181>> => ".BaseNFT.invoke_nft_receiver",
       <<93, 142, 50, 216>> => ".^1697",
       <<94, 119, 225, 37>> => ".List.foldl",
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

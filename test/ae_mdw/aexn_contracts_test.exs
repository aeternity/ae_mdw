defmodule AeMdw.AexnContractsTest do
  use ExUnit.Case

  alias AeMdw.AexnContracts

  import Mock
  import AeMdw.AexnFixtures

  defp max_height, do: AeMdw.Util.max_int()

  describe "call_meta_info/2" do
    test "succeeds with regular aex9 meta_info" do
      contract_pk = :crypto.strong_rand_bytes(32)
      mb_hash = <<Enum.random(100_000..999_999)::256>>

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn ^mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, {:micro, 123, ^mb_hash}, "meta_info", [] ->
             meta_info_tuple = {"name", "SYM", 18}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYM", 18}} =
                 AexnContracts.call_meta_info(:aex9, contract_pk, mb_hash)
      end
    end

    test "succeeds with rearranged aex9 meta_info 1" do
      contract_pk = :crypto.strong_rand_bytes(32)
      mb_hash = <<Enum.random(100_000..999_999)>>

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn ^mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, {:micro, 123, ^mb_hash}, "meta_info", [] ->
             meta_info_tuple = {"Abc", 18, "ABC"}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"Abc", "ABC", 18}} =
                 AexnContracts.call_meta_info(:aex9, contract_pk, mb_hash)
      end
    end

    test "succeeds with rearranged aex9 meta_info 2" do
      contract_pk = :crypto.strong_rand_bytes(32)
      mb_hash = <<Enum.random(100_000..999_999)::256>>

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn ^mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, {:micro, 123, ^mb_hash}, "meta_info", [] ->
             meta_info_tuple = {"ABC", "Abc", 18}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"Abc", "ABC", 18}} =
                 AexnContracts.call_meta_info(:aex9, contract_pk, mb_hash)
      end
    end

    test "succeeds with rearranged aex9 meta_info 3" do
      contract_pk = :crypto.strong_rand_bytes(32)
      mb_hash = <<Enum.random(100_000..999_999)::256>>

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn ^mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, {:micro, 123, ^mb_hash}, "meta_info", [] ->
             meta_info_tuple = {"ABC", 18, "Abc"}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"Abc", "ABC", 18}} =
                 AexnContracts.call_meta_info(:aex9, contract_pk, mb_hash)
      end
    end

    test "succeeds with rearranged aex9 meta_info 4" do
      contract_pk = :crypto.strong_rand_bytes(32)
      mb_hash = <<Enum.random(100_000..999_999)::256>>

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn ^mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, {:micro, 123, ^mb_hash}, "meta_info", [] ->
             meta_info_tuple = {18, "Abc", "ABC"}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"Abc", "ABC", 18}} =
                 AexnContracts.call_meta_info(:aex9, contract_pk, mb_hash)
      end
    end

    test "succeeds with rearranged aex9 meta_info 5" do
      contract_pk = :crypto.strong_rand_bytes(32)
      mb_hash = <<Enum.random(100_000..999_999)::256>>

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn ^mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, {:micro, 123, ^mb_hash}, "meta_info", [] ->
             meta_info_tuple = {18, "ABC", "Abc"}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"Abc", "ABC", 18}} =
                 AexnContracts.call_meta_info(:aex9, contract_pk, mb_hash)
      end
    end

    test "succeeds with meta info from previous nft draft (hackaton)" do
      contract_pk = :crypto.strong_rand_bytes(32)
      mb_hash = <<Enum.random(100_000..999_999)::256>>
      base_url = "https://some-base-url.com"

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn ^mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, {:micro, 123, ^mb_hash}, "meta_info", [] ->
             variant_url = {:variant, [0, 1], 1, base_url}
             variant_type = {:variant, [0, 0, 0, 0], 0, {}}
             meta_info_tuple = {"name", "SYM", variant_url, variant_type}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYM", ^base_url, :url}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk, mb_hash)
      end
    end

    test "succeeds with nft standard meta info without base url" do
      contract_pk = :crypto.strong_rand_bytes(32)
      mb_hash = <<Enum.random(100_000..999_999)::256>>

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn ^mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, {:micro, 123, ^mb_hash}, "meta_info", [] ->
             variant_url = {:variant, [0, 1], 0, {}}
             variant_type = {:variant, [0, 0, 0], 2, {}}
             meta_info_tuple = {"name", "SYM", variant_url, variant_type}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYM", nil, :map}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk, mb_hash)
      end
    end

    test "succeeds with nft standard meta info with base url" do
      contract_pk = :crypto.strong_rand_bytes(32)
      mb_hash = <<Enum.random(100_000..999_999)::256>>

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn ^mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, {:micro, 123, ^mb_hash}, "meta_info", [] ->
             variant_url = {:variant, [0, 1], 1, "http://baseurl"}
             variant_type = {:variant, [0, 0, 0], 2, {}}
             meta_info_tuple = {"name", "SYM", variant_url, variant_type}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYM", "http://baseurl", :map}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk, mb_hash)
      end
    end

    test "succeeds with nft rearranged meta info 1" do
      contract_pk = :crypto.strong_rand_bytes(32)
      mb_hash = <<Enum.random(100_000..999_999)::256>>

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn ^mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, {:micro, 123, ^mb_hash}, "meta_info", [] ->
             variant_url = {:variant, [0, 1], 0, ""}
             variant_type = {:variant, [0, 0, 0], 2, {}}
             meta_info_tuple = {"name", variant_url, "SYM", variant_type}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYM", nil, :map}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk, mb_hash)
      end
    end

    test "succeeds with nft rearranged meta info 2" do
      contract_pk = :crypto.strong_rand_bytes(32)
      mb_hash = <<Enum.random(100_000..999_999)::256>>

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn ^mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, {:micro, 123, ^mb_hash}, "meta_info", [] ->
             variant_url = {:variant, [0, 1], 0, ""}
             variant_type = {:variant, [0, 0, 0], 2, {}}
             meta_info_tuple = {"name", variant_url, variant_type, "SYM"}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYM", nil, :map}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk, mb_hash)
      end
    end

    test "succeeds with nft rearranged meta info 3" do
      contract_pk = :crypto.strong_rand_bytes(32)
      mb_hash = <<Enum.random(100_000..999_999)::256>>

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn ^mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, {:micro, 123, ^mb_hash}, "meta_info", [] ->
             variant_url = {:variant, [0, 1], 0, ""}
             variant_type = {:variant, [0, 0, 0], 2, {}}
             meta_info_tuple = {"SYM", "name", variant_url, variant_type}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYM", nil, :map}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk, mb_hash)
      end
    end

    test "succeeds with nft rearranged meta info 4" do
      contract_pk = :crypto.strong_rand_bytes(32)
      mb_hash = <<Enum.random(100_000..999_999)::256>>

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn ^mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, {:micro, 123, ^mb_hash}, "meta_info", [] ->
             variant_url = {:variant, [0, 1], 0, ""}
             variant_type = {:variant, [0, 0, 0], 2, {}}
             meta_info_tuple = {"SYM", variant_url, variant_type, "name"}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYM", nil, :map}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk, mb_hash)
      end
    end

    test "returns :unknown metadata type when does not comply to nft standard" do
      contract_pk = :crypto.strong_rand_bytes(32)
      mb_hash = <<Enum.random(100_000..999_999)::256>>

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn ^mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, {:micro, 123, ^mb_hash}, "meta_info", [] ->
             variant_url = {:variant, [0, 1], 0, ""}
             variant_type = {:variant, [0, 0], 0, {}}
             meta_info_tuple = {"name", "SYM", variant_url, variant_type}
             {:ok, {:tuple, meta_info_tuple}}
           end
         ]}
      ] do
        assert {:ok, {"name", "SYM", nil, :unknown}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk, mb_hash)
      end
    end

    test "returns format error values when tuple format is unexpected" do
      contract_pk = :crypto.strong_rand_bytes(32)
      mb_hash = <<Enum.random(100_000..999_999)::256>>

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn ^mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, {:micro, 123, ^mb_hash}, "meta_info", [] ->
             {:ok, {:tuple, {"name", "symbol"}}}
           end
         ]}
      ] do
        assert {:ok, {:format_error, :format_error, nil}} =
                 AexnContracts.call_meta_info(:aex9, contract_pk, mb_hash)
      end
    end

    test "returns out of gas error when call_contract fails" do
      contract_pk = :crypto.strong_rand_bytes(32)
      mb_hash = <<Enum.random(100_000..999_999)::256>>

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn ^mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, {:micro, 123, ^mb_hash}, "meta_info", [] ->
             {:error, :dry_run_error}
           end
         ]}
      ] do
        assert {:ok, {:out_of_gas_error, :out_of_gas_error, :out_of_gas_error, nil}} =
                 AexnContracts.call_meta_info(:aex141, contract_pk, mb_hash)
      end
    end

    test "returns error when block is not found" do
      contract_pk = :crypto.strong_rand_bytes(32)
      assert :error = AexnContracts.call_meta_info(:aex141, contract_pk, <<0::256>>)
    end

    test "returns error when contract does not exist" do
      contract_pk = :crypto.strong_rand_bytes(32)
      mb_hash = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AeMdw.Node.Db, [:passthrough],
         [
           find_block_height: fn ^mb_hash -> {:ok, 123} end
         ]},
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, {:micro, 123, ^mb_hash}, "meta_info", [] ->
             {:error, :contract_does_not_exist}
           end
         ]}
      ] do
        assert :error = AexnContracts.call_meta_info(:aex141, contract_pk, mb_hash)
      end
    end
  end

  describe "has_valid_aex141_extensions?/3" do
    test "returns for a immediate mintable" do
      extensions = ["mintable"]
      type_info = unique_nfts_contract_fcode(extensions: extensions)

      assert AexnContracts.has_valid_aex141_extensions?(extensions, type_info)
    end

    test "returns true for immediate mintable and burnable" do
      extensions = ["mintable", "burnable"]
      type_info = unique_nfts_contract_fcode(extensions: extensions)

      assert AexnContracts.has_valid_aex141_extensions?(extensions, type_info)
    end

    test "returns false for different mintable" do
      extensions = ["mintable", "burnable"]
      type_info = unique_nfts_contract_fcode(wrong_mint: true, extensions: extensions)

      refute AexnContracts.has_valid_aex141_extensions?(extensions, type_info)
    end

    test "returns false for different burnable" do
      extensions = ["mintable", "burnable"]
      type_info = unique_nfts_contract_fcode(wrong_burn: true, extensions: extensions)

      refute AexnContracts.has_valid_aex141_extensions?(extensions, type_info)
    end
  end

  describe "has_aex141_signatures?/2" do
    test "returns true for new nft contracts" do
      assert max_height() |> AexnContracts.has_aex141_signatures?(unique_nfts_contract_fcode())
    end

    test "returns true for previous base nft at previous spec" do
      assert AexnContracts.has_aex141_signatures?(600_000, base_nft_fcode())
    end

    test "returns false for incomplete previous base nft at previous spec" do
      refute AexnContracts.has_aex141_signatures?(600_000, incomplete_base_nft_fcode())
    end

    test "returns false for previous base nft" do
      refute max_height() |> AexnContracts.has_aex141_signatures?(base_nft_fcode())
    end
  end

  describe "get_extensions/3" do
    test "returns for immediate mintable" do
      contract_pk = :crypto.strong_rand_bytes(32)
      extensions = ["mintable", "burnable"]
      type_info = unique_nfts_contract_fcode(extensions: extensions)
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})
      assert {:ok, ^extensions} = AexnContracts.get_extensions(:aex141, contract_pk, type_info)
    end

    test "returns for not immediate mintable" do
      contract_pk = :crypto.strong_rand_bytes(32)
      extensions = ["mintable"]
      type_info = unique_nfts_contract_fcode(not_immediate: true)
      AeMdw.EtsCache.put(AeMdw.Contract, contract_pk, {type_info, nil, nil})

      with_mocks [
        {AeMdw.DryRun.Runner, [:passthrough],
         [
           call_contract: fn ^contract_pk, _hash, "aex141_extensions", [] ->
             {:ok, extensions}
           end
         ]}
      ] do
        assert {:ok, ^extensions} = AexnContracts.get_extensions(:aex141, contract_pk, type_info)
      end
    end

    test "returns error when contract does not exist" do
      contract_pk = :crypto.strong_rand_bytes(32)
      type_info = unique_nfts_contract_fcode(not_immediate: true)
      assert :error = AexnContracts.get_extensions(:aex141, contract_pk, type_info)
    end
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

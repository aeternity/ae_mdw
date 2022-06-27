defmodule AeMdwWeb.Aex141ControllerTest do
  use AeMdwWeb.ConnCase

  alias AeMdw.AexnContracts
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Validate

  import AeMdwWeb.Helpers.AexnHelper, only: [enc_ct: 1, enc_id: 1]
  import Mock

  require Model

  @owner_pk :crypto.strong_rand_bytes(32)
  @default_limit 10

  setup_all _context do
    Enum.each(1_411..1_413, fn i ->
      meta_info = {"some-nft-#{i}", "SAEX#{i}", "http://some-url.com", :url}
      txi = 1_000 + i
      m_aex141 = Model.aexn_contract(index: {:aex141, <<i::256>>}, txi: txi, meta_info: meta_info)
      Database.dirty_write(Model.AexnContract, m_aex141)
    end)

    Enum.each(1_412_001..1_412_010, fn j ->
      m_aex141 = Model.nft_ownership(index: {@owner_pk, <<div(j, 1_000)::256>>, j})
      Database.dirty_write(Model.NftOwnership, m_aex141)
    end)

    m_aex141 =
      Model.nft_ownership(index: {:crypto.strong_rand_bytes(32), <<1413::256>>, 1_413_001})

    Database.dirty_write(Model.NftOwnership, m_aex141)

    Enum.each(1_413_002..1_413_011, fn j ->
      m_aex141 = Model.nft_ownership(index: {@owner_pk, <<div(j, 1_000)::256>>, j})
      Database.dirty_write(Model.NftOwnership, m_aex141)
    end)

    :ok
  end

  describe "nft_owner" do
    test "returns the account that owns a nft", %{conn: conn} do
      contract_id = enc_ct(<<1_411::256>>)
      account_pk = :crypto.strong_rand_bytes(32)

      with_mocks [
        {AexnContracts, [],
         [
           is_aex141?: fn pk -> pk == <<1_411::256>> end,
           call_contract: fn _pk, "owner", [_token_id] -> {:ok, {:address, account_pk}} end
         ]}
      ] do
        assert %{"data" => account_id} =
                 conn |> get("/aex141/#{contract_id}/owner/#{123}") |> json_response(200)

        assert {:ok, ^account_pk} = Validate.id(account_id)
      end
    end

    test "returns an error when not an aex141 contract", %{conn: conn} do
      non_existent_id = "ct_y7gojSY8rXW6tztE9Ftqe3kmNrqEXsREiPwGCeG3MJL38jkFo"
      error_msg = "not AEX141 contract: #{non_existent_id}"

      assert %{"error" => ^error_msg} =
               conn |> get("/aex141/#{non_existent_id}/owner/#{123}") |> json_response(400)
    end

    test "returns an error when token doesn't exist", %{conn: conn} do
      contract_id = enc_ct(<<1_411::256>>)
      error_msg = "invalid return of contract: #{contract_id}"

      with_mocks [
        {AexnContracts, [],
         [
           is_aex141?: fn pk -> pk == <<1_411::256>> end,
           call_contract: fn _pk, "owner", [_token_id] -> {:ok, nil} end
         ]}
      ] do
        assert %{"error" => ^error_msg} =
                 conn |> get("/aex141/#{contract_id}/owner/#{234}") |> json_response(400)
      end
    end
  end

  describe "owned_nfts" do
    test "returns an empty list when account owns none", %{conn: conn} do
      account_id = enc_id(:crypto.strong_rand_bytes(32))

      assert %{"data" => [], "next" => nil, "prev" => nil} =
               conn |> get("/aex141/owned_nfts/#{account_id}") |> json_response(200)
    end

    test "returns a backward list of nfts owned by an account", %{conn: conn} do
      account_id = enc_id(@owner_pk)

      assert %{"data" => nfts, "next" => next} =
               conn |> get("/aex141/owned_nfts/#{account_id}") |> json_response(200)

      assert @default_limit = length(nfts)
      assert ^nfts = Enum.sort(nfts, :desc)

      assert %{"data" => next_nfts, "prev" => prev_nfts} = conn |> get(next) |> json_response(200)

      assert @default_limit = length(next_nfts)
      assert ^next_nfts = Enum.sort(next_nfts, :desc)

      assert %{"data" => ^nfts} = conn |> get(prev_nfts) |> json_response(200)
    end

    test "returns a forward list of nfts owned by an account", %{conn: conn} do
      account_id = enc_id(@owner_pk)

      assert %{"data" => nfts, "next" => next} =
               conn
               |> get("/aex141/owned_nfts/#{account_id}", direction: :forward)
               |> json_response(200)

      assert @default_limit = length(nfts)
      assert ^nfts = Enum.sort(nfts)

      refute Enum.any?(nfts, fn %{"token_id" => token_id} -> token_id == 1_413_001 end)

      assert %{"data" => next_nfts, "prev" => prev_nfts} = conn |> get(next) |> json_response(200)

      assert @default_limit = length(next_nfts)
      assert ^next_nfts = Enum.sort(next_nfts)

      assert %{"data" => ^nfts} = conn |> get(prev_nfts) |> json_response(200)
    end
  end
end

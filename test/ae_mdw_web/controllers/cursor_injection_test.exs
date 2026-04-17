defmodule AeMdwWeb.CursorInjectionTest do
  @moduledoc """
  Security regression tests for C-1: atom table exhaustion via unsafe binary_to_term.

  These tests verify that endpoints using ETF-based cursor deserialization:
    1. Return 400 (or otherwise handle gracefully) for malformed cursor values.
    2. Do NOT create new atoms in the atom table when given a crafted ETF payload
       containing atoms not yet known to the runtime — the key property of the
       [:safe] option added as the C-1 fix.

  Payload construction avoids calling :erlang.binary_to_term or
  String.to_atom/1 so that the novel atom genuinely does not exist in
  the atom table before the request is made.
  """

  use AeMdwWeb.ConnCase
  @moduletag skip_store: true

  # A 32-byte zeroed public key used in path segments.
  @zeroed_pk <<0::256>>

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Builds a valid ETF binary whose sole term is an atom with the given
  # UTF-8 name. The binary is constructed byte-by-byte; no atom is created
  # in the current process.
  #
  # ETF format: <<131, ATOM_UTF8_EXT(118), length::16-big, name_bytes>>
  defp novel_atom_etf(atom_name) when is_binary(atom_name) do
    len = byte_size(atom_name)
    <<131, 118, len::16-big, atom_name::binary>>
  end

  # Returns true when the string already corresponds to an existing atom.
  defp atom_exists?(name) when is_binary(name) do
    _atom = String.to_existing_atom(name)
    true
  rescue
    ArgumentError -> false
  end

  # ---------------------------------------------------------------------------
  # Tests: endpoints that return 400 for invalid cursors
  # ---------------------------------------------------------------------------

  describe "aexn transfers — base64 ETF cursor" do
    # Uses /v3/aex141/transfers which deserializes the cursor before any DB lookup
    # (no required query params, validated in fetch_aex141_transfers/4).

    test "random non-base64 string returns 400", %{conn: conn} do
      cursor = "!!!not-valid-base64!!!"

      assert %{"error" => "invalid cursor: " <> _} =
               conn
               |> get("/v3/aex141/transfers", cursor: cursor)
               |> json_response(400)
    end

    test "base64 of random bytes returns 400", %{conn: conn} do
      cursor = Base.encode64("not_valid_etf_at_all")

      assert %{"error" => "invalid cursor: " <> _} =
               conn
               |> get("/v3/aex141/transfers", cursor: cursor)
               |> json_response(400)
    end

    test "ETF with novel atom is rejected and does not grow the atom table", %{conn: conn} do
      unique = "ae_mdw_aexn_transfer_inject_#{System.unique_integer([:positive])}"
      refute atom_exists?(unique), "precondition: atom must not exist before the request"

      cursor = unique |> novel_atom_etf() |> Base.encode64()

      assert %{"error" => "invalid cursor: " <> _} =
               conn
               |> get("/v3/aex141/transfers", cursor: cursor)
               |> json_response(400)

      refute atom_exists?(unique), "novel atom MUST NOT be created after the request"
    end
  end

  describe "aex141 owned tokens — base64 ETF cursor" do
    # Uses /v3/accounts/:id/aex141/tokens which calls fetch_owned_tokens/5.
    # The cursor is deserialized after account_pk validation but before any DB
    # lookup, so it returns 400 for invalid cursors regardless of whether the
    # account has any NFTs.

    test "base64 of random bytes returns 400", %{conn: conn} do
      account_id = encode_account(@zeroed_pk)
      cursor = Base.encode64("not_etf")

      assert %{"error" => "invalid cursor: " <> _} =
               conn
               |> get("/v3/accounts/#{account_id}/aex141/tokens", cursor: cursor)
               |> json_response(400)
    end

    test "ETF with novel atom is rejected and does not grow the atom table", %{conn: conn} do
      unique = "ae_mdw_aex141_tokens_inject_#{System.unique_integer([:positive])}"
      refute atom_exists?(unique)

      account_id = encode_account(@zeroed_pk)
      cursor = unique |> novel_atom_etf() |> Base.encode64()

      assert %{"error" => "invalid cursor: " <> _} =
               conn
               |> get("/v3/accounts/#{account_id}/aex141/tokens", cursor: cursor)
               |> json_response(400)

      refute atom_exists?(unique)
    end
  end

  describe "account dex swaps — hex32 ETF cursor" do
    test "random non-hex32 string returns 400", %{conn: conn} do
      account_id = encode_account(@zeroed_pk)
      cursor = "!!!not-hex32!!!"

      assert %{"error" => "invalid cursor: " <> _} =
               conn
               |> get("/v3/accounts/#{account_id}/dex/swaps", cursor: cursor)
               |> json_response(400)
    end

    test "hex32 of random bytes returns 400", %{conn: conn} do
      account_id = encode_account(@zeroed_pk)
      cursor = Base.hex_encode32("not_etf_data", padding: false)

      assert %{"error" => "invalid cursor: " <> _} =
               conn
               |> get("/v3/accounts/#{account_id}/dex/swaps", cursor: cursor)
               |> json_response(400)
    end

    test "ETF with novel atom is rejected and does not grow the atom table", %{conn: conn} do
      unique = "ae_mdw_dex_acct_inject_#{System.unique_integer([:positive])}"
      refute atom_exists?(unique)

      account_id = encode_account(@zeroed_pk)
      cursor = unique |> novel_atom_etf() |> Base.hex_encode32(padding: false)

      assert %{"error" => "invalid cursor: " <> _} =
               conn
               |> get("/v3/accounts/#{account_id}/dex/swaps", cursor: cursor)
               |> json_response(400)

      refute atom_exists?(unique)
    end
  end

  describe "global dex swaps — hex32 ETF cursor" do
    test "ETF with novel atom is rejected and does not grow the atom table", %{conn: conn} do
      unique = "ae_mdw_dex_global_inject_#{System.unique_integer([:positive])}"
      refute atom_exists?(unique)

      cursor = unique |> novel_atom_etf() |> Base.hex_encode32(padding: false)

      assert %{"error" => "invalid cursor: " <> _} =
               conn
               |> get("/v3/dex/swaps", cursor: cursor)
               |> json_response(400)

      refute atom_exists?(unique)
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: endpoints where an invalid cursor is silently ignored (no 400),
  # but the atom table must still not grow.
  # ---------------------------------------------------------------------------

  describe "names listing — base64 ETF cursor (invalid cursor treated as nil)" do
    test "invalid base64 cursor is ignored — no atom created", %{conn: conn} do
      unique = "ae_mdw_names_inject_#{System.unique_integer([:positive])}"
      refute atom_exists?(unique)

      # names uses Base.decode64 with padding: false
      cursor = unique |> novel_atom_etf() |> Base.encode64(padding: false)

      # The endpoint silently ignores an invalid cursor and returns the first page.
      # What matters is that no atom is created.
      conn |> get("/v3/names", cursor: cursor)

      refute atom_exists?(unique)
    end
  end

end

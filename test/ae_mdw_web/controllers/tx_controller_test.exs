defmodule AeMdwWeb.TxControllerTest do
  use AeMdwWeb.ConnCase, async: false

  import Mock

  alias AeMdw.Db.Model
  alias AeMdw.Db.Store
  alias AeMdw.Db.Util
  alias AeMdw.TestSamples, as: TS

  require Model

  describe "txs" do
    test "it returns 400 when no direction specified", %{conn: conn} do
      with_mocks [
        {Util, [],
         [
           last_gen: fn _state -> 1_000 end
         ]}
      ] do
        assert %{"error" => "no such route"} = conn |> get("/txs") |> json_response(400)
      end
    end
  end

  describe "tx" do
    test "when tx not found, it returns 404", %{conn: conn} do
      tx_hash = "th_2TbTPmKFU31WNQKfBGe5b5JDF9sFdAY7qot1smnxjbsEiu7LNr"

      assert %{"error" => _error_msg} = conn |> get("/tx/#{tx_hash}") |> json_response(404)
    end
  end

  describe "count" do
    test "it returns all tx count by default", %{conn: conn, store: store} do
      tx = Model.tx(index: tx_index) = TS.tx(0)
      store = Store.put(store, Model.Tx, tx)

      assert ^tx_index =
               conn
               |> with_store(store)
               |> get("/txs/count")
               |> json_response(200)
    end

    test "it returns the difference between first and last txi", %{conn: conn} do
      first_txi = 600
      last_txi = 500

      assert 101 =
               conn
               |> get("/txs/count", scope: "txi:#{first_txi}-#{last_txi}")
               |> json_response(200)
    end

    test "it returns error when filtering by type", %{conn: conn} do
      error_msg = "invalid query: counting by type not yet supported"

      assert %{"error" => ^error_msg} =
               conn
               |> get("/txs/count", type: "spend")
               |> json_response(400)
    end
  end
end

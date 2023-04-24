defmodule AeMdwWeb.UtilControllerTest do
  @moduledoc false

  use AeMdwWeb.ConnCase

  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Model

  require Model

  import AeMdw.Util.Encoding, only: [encode_account: 1]

  describe "wealth" do
    test "gets the biggest balances in descending order", %{conn: conn} do
      balance1 = 200
      a1 = <<1::256>>
      account1 = encode_account(a1)
      balance2 = 100
      a2 = <<2::256>>
      account2 = encode_account(a2)

      store =
        AsyncStore.instance()
        |> AsyncStore.put(Model.BalanceAccount, Model.balance_account(index: {balance2, a2}))
        |> AsyncStore.put(Model.BalanceAccount, Model.balance_account(index: {balance1, a1}))

      assert [
               %{"balance" => balance1, "account" => account1},
               %{"balance" => balance2, "account" => account2}
             ] ==
               conn
               |> with_store(store)
               |> get("/v2/wealth")
               |> json_response(200)
    end
  end
end

defmodule AeMdwWeb.CallsViewTest do
  use ExUnit.Case, async: false

  alias AeMdwWeb.CallsView

  describe "render_call/2" do
    setup do
      call = %{
        block_hash: "mh_2RoqVE3xDJTgXZM1svnmbqmPkBCkS5opE2xjNmzXrBNsznAsrk",
        call_tx_hash: "th_111111111111111111111111111112A5TAATAXs",
        call_txi: 2_000_027,
        contract_id: "ct_22d4VVjbf3WFsfvy3fYa4LF12i6nBPweMSfCNR5QWKfmae6JnF",
        contract_tx_hash: "th_11111111111111111111111111111aY5u5VsDU",
        contract_txi: 999_941,
        function: "Chain.spend",
        height: 201,
        internal_tx: %{
          "amount" => 1_000_000_000_000_000_000,
          "fee" => 0,
          "nonce" => 0,
          "payload" => "ba_Q2hhaW4uc3BlbmRFa4Tl",
          "recipient_id" => "ak_111111111111111111111111111112A5TAATAXs",
          "sender_id" => "ak_11111111111111111111111111111118qjnEr",
          "type" => "SpendTx",
          "version" => 1
        },
        local_idx: 0,
        micro_index: 1
      }

      %{call: call}
    end

    test "v2 renders a call", %{call: call} do
      call = CallsView.render_call(call, false)

      assert Map.has_key?(call, :call_txi)
      assert Map.has_key?(call, :contract_txi)
    end

    test "v3 renders a call", %{call: call} do
      call = CallsView.render_call(call, true)

      refute Map.has_key?(call, :call_txi)
      refute Map.has_key?(call, :contract_txi)
    end
  end
end

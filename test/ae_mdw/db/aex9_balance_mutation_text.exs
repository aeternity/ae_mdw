defmodule AeMdw.Db.Aex9AccountBalanceMutationTest do
  use ExUnit.Case

  alias AeMdw.Database
  alias AeMdw.Db.Aex9AccountBalanceMutation
  alias AeMdw.Db.Model

  require Model

  @ct_pk1 <<1::256>>
  @ct_pk2 <<2::256>>
  # @ct_pk3 <<3::256>>
  # @ct_pk4 <<4::256>>
  # @ct_pk5 <<5::256>>

  @initial_amount 1_000_000

  @some_caller_pk <<10::256>>

  @burn_pk <<11::256>>
  @swap_pk <<12::256>>
  @mint_pk <<13::256>>
  @transfer_pk1 <<141::256>>
  @transfer_pk2 <<142::256>>
  @transfer_allowance_pk1 <<151::256>>
  @transfer_allowance_pk2 <<152::256>>
  @other_call_pk1 <<161::256>>
  @other_call_pk2 <<162::256>>

  @block_index1 {1234, 0}

  setup_all _ctx do
    Enum.each(
      [
        @burn_pk,
        @swap_pk,
        @mint_pk,
        @transfer_pk1,
        @transfer_pk2,
        @transfer_allowance_pk1,
        @transfer_allowance_pk2
      ],
      fn account_pk ->
        Database.dirty_write(
          Model.Aex9Balance,
          Model.aex9_balance(
            index: {@ct_pk1, account_pk},
            block_index: @block_index1,
            amount: @initial_amount
          )
        )
      end
    )

    Enum.each(
      [
        @other_call_pk1,
        @other_call_pk2
      ],
      fn account_pk ->
        Database.dirty_write(
          Model.Aex9Balance,
          Model.aex9_balance(
            index: {@ct_pk2, account_pk},
            block_index: @block_index1,
            amount: @initial_amount
          )
        )
      end
    )

    :ok
  end

  test "update aex9 balance after a burn" do
    burn_value = 1000

    mutation =
      Aex9AccountBalanceMutation.new(
        "burn",
        [%{type: :int, value: burn_value}],
        @ct_pk1,
        @burn_pk
      )

    Database.commit([mutation])

    expected_balance =
      Model.aex9_balance(
        index: {@ct_pk1, @burn_pk},
        block_index: @block_index1,
        amount: @initial_amount - burn_value
      )

    assert ^expected_balance = Database.fetch!(Model.Aex9Balance, {@ct_pk1, @burn_pk})
  end

  test "update aex9 balance after a swap" do
    mutation = Aex9AccountBalanceMutation.new("swap", [], @ct_pk1, @swap_pk)

    Database.commit([mutation])

    expected_balance =
      Model.aex9_balance(index: {@ct_pk1, @swap_pk}, block_index: @block_index1, amount: nil)

    assert ^expected_balance = Database.fetch!(Model.Aex9Balance, {@ct_pk1, @swap_pk})
  end

  test "update aex9 balance after a mint" do
    minted_value = 2_000_000

    mutation =
      Aex9AccountBalanceMutation.new(
        "mint",
        [
          %{type: :address, value: @mint_pk},
          %{type: :int, value: minted_value}
        ],
        @ct_pk1,
        @some_caller_pk
      )

    Database.commit([mutation])

    expected_balance =
      Model.aex9_balance(
        index: {@ct_pk1, @mint_pk},
        block_index: @block_index1,
        amount: @initial_amount + minted_value
      )

    assert ^expected_balance = Database.fetch!(Model.Aex9Balance, {@ct_pk1, @mint_pk})
  end

  test "update aex9 balance after a transer" do
    transfer_value = 234_567_890

    mutation =
      Aex9AccountBalanceMutation.new(
        "transfer",
        [
          %{type: :address, value: @transfer_pk2},
          %{type: :int, value: transfer_value}
        ],
        @ct_pk1,
        @transfer_pk1
      )

    Database.commit([mutation])

    expected_balance1 =
      Model.aex9_balance(
        index: {@ct_pk1, @transfer_pk1},
        block_index: @block_index1,
        amount: @initial_amount - transfer_value
      )

    expected_balance2 =
      Model.aex9_balance(
        index: {@ct_pk1, @transfer_pk2},
        block_index: @block_index1,
        amount: @initial_amount + transfer_value
      )

    assert ^expected_balance1 = Database.fetch!(Model.Aex9Balance, {@ct_pk1, @transfer_pk1})

    assert ^expected_balance2 = Database.fetch!(Model.Aex9Balance, {@ct_pk1, @transfer_pk2})
  end

  test "update aex9 balance after a transer allowance" do
    transfer_value = 234_567_891

    mutation =
      Aex9AccountBalanceMutation.new(
        "transfer_allowance",
        [
          %{type: :address, value: @transfer_allowance_pk1},
          %{type: :address, value: @transfer_allowance_pk2},
          %{type: :int, value: transfer_value}
        ],
        @ct_pk1,
        @some_caller_pk
      )

    Database.commit([mutation])

    expected_balance1 =
      Model.aex9_balance(
        index: {@ct_pk1, @transfer_allowance_pk1},
        block_index: @block_index1,
        amount: @initial_amount - transfer_value
      )

    expected_balance2 =
      Model.aex9_balance(
        index: {@ct_pk1, @transfer_allowance_pk2},
        block_index: @block_index1,
        amount: @initial_amount + transfer_value
      )

    assert ^expected_balance1 =
             Database.fetch!(Model.Aex9Balance, {@ct_pk1, @transfer_allowance_pk1})

    assert ^expected_balance2 =
             Database.fetch!(Model.Aex9Balance, {@ct_pk1, @transfer_allowance_pk2})
  end

  test "invalidate aex9 balance on untrackable call" do
    some_value = 1000

    mutation =
      Aex9AccountBalanceMutation.new(
        "burn_and_something",
        [%{type: :int, value: some_value}],
        @ct_pk2,
        @other_call_pk1
      )

    Database.commit([mutation])

    assert :not_found = Database.fetch(Model.Aex9Balance, {@ct_pk2, @other_call_pk1})
    assert :not_found = Database.fetch(Model.Aex9Balance, {@ct_pk2, @other_call_pk2})
  end
end

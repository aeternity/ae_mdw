defmodule AeMdw.Db.ContractTest do
  use ExUnit.Case

  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Validate

  alias Support.AeMdw.Db.ContractTestUtil

  require Ex2ms
  require Model

  @existing_cpk Validate.id!("ct_2uQYkMmupmAvBtSGtVLyua4EmcPAY62gKo4bSFEmfCNeNK9THX")
  @existing_apk Validate.id!("ak_eYHyfKSZiU3nzDTJBkrXAzVszoxDU4DHDw5xz6f2i5YVME234")
  @new_cpk Validate.id!("ct_2QKWLinRRozwA6wPAnW269hCHpkL1vcb2YCTrna94nP7rAPVU9")

  test "new aex9 presence not created when already exists" do
    txi = 1_000_123

    Contract.aex9_write_presence(@existing_cpk, txi, @existing_apk)

    assert @existing_cpk
           |> ContractTestUtil.aex9_presence_txi_list(@existing_apk)
           |> Enum.find(&(&1 == txi))

    Contract.aex9_write_new_presence(@existing_cpk, txi + 1, @existing_apk)

    refute @existing_cpk
           |> ContractTestUtil.aex9_presence_txi_list(@existing_apk)
           |> Enum.find(&(&1 == txi + 1))
  end

  test "create and delete new aex9 presence" do
    assert [] == ContractTestUtil.aex9_presence_txi_list(@new_cpk, @existing_apk)

    Contract.aex9_write_new_presence(@new_cpk, -1, @existing_apk)
    assert [-1] == ContractTestUtil.aex9_presence_txi_list(@new_cpk, @existing_apk)

    ContractTestUtil.aex9_delete_presence(@new_cpk, @existing_apk)
    assert [] == ContractTestUtil.aex9_presence_txi_list(@new_cpk, @existing_apk)
  end
end

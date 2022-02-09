defmodule AeMdw.Db.ContractTest do
  use ExUnit.Case

  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Validate

  import Support.TestMnesiaSandbox

  require Ex2ms
  require Model

  @existing_cpk Validate.id!("ct_2uQYkMmupmAvBtSGtVLyua4EmcPAY62gKo4bSFEmfCNeNK9THX")
  @existing_apk Validate.id!("ak_eYHyfKSZiU3nzDTJBkrXAzVszoxDU4DHDw5xz6f2i5YVME234")
  @new_cpk Validate.id!("ct_2QKWLinRRozwA6wPAnW269hCHpkL1vcb2YCTrna94nP7rAPVU9")

  test "new aex9 presence not created when already exists" do
    fn ->
      fake_txi = 1_000_123
      Contract.aex9_write_presence(@existing_cpk, fake_txi, @existing_apk)

      assert @existing_cpk
             |> aex9_presence_txi_list(@existing_apk)
             |> Enum.find(&(&1 == fake_txi))

      Contract.aex9_write_new_presence(@existing_cpk, fake_txi + 1, @existing_apk)

      refute @existing_cpk
             |> aex9_presence_txi_list(@existing_apk)
             |> Enum.find(&(&1 == fake_txi + 1))

      :mnesia.abort(:rollback)
    end
    |> mnesia_sandbox()
  end

  test "create and delete new aex9 presence" do
    fn ->
      assert [] == aex9_presence_txi_list(@new_cpk, @existing_apk)
      Contract.aex9_write_new_presence(@new_cpk, -1, @existing_apk)

      assert [-1] == aex9_presence_txi_list(@new_cpk, @existing_apk)
      Contract.aex9_delete_presence(@new_cpk, -1, @existing_apk)
      assert [] == aex9_presence_txi_list(@new_cpk, @existing_apk)

      :mnesia.abort(:rollback)
    end
    |> mnesia_sandbox()
  end

  defp aex9_presence_txi_list(contract_pk, account_pk) do
    record_name = Model.record(Model.Aex9AccountPresence)

    presence_spec =
      Ex2ms.fun do
        {^record_name, {^account_pk, txi, ^contract_pk}, :_} ->
          txi
      end

    :mnesia.select(Model.Aex9AccountPresence, presence_spec, :read)
  end
end

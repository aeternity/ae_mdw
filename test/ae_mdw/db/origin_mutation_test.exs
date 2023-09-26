defmodule AeMdw.Db.OriginMutationTest do
  use AeMdw.Db.MutationCase, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.OriginMutation
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.ObjectKeys

  require Model

  describe "execute" do
    test "puts contracts, creates origin, reverse origin and field records" do
      :ets.delete_all_objects(:db_contracts)

      state =
        OriginMutation.execute(
          OriginMutation.new(:contract_create_tx, <<1::256>>, 121, <<121::256>>),
          empty_state()
        )

      state =
        OriginMutation.execute(
          OriginMutation.new(:contract_call_tx, <<2::256>>, 122, <<122::256>>),
          state
        )

      state =
        OriginMutation.execute(
          OriginMutation.new(:ga_attach_tx, <<3::256>>, 123, <<123::256>>),
          state
        )

      assert State.exists?(state, Model.Origin, {:contract_create_tx, <<1::256>>, 121})
      assert State.exists?(state, Model.Origin, {:contract_call_tx, <<2::256>>, 122})
      assert State.exists?(state, Model.Origin, {:ga_attach_tx, <<3::256>>, 123})

      assert State.exists?(state, Model.RevOrigin, {121, :contract_create_tx, <<1::256>>})
      assert State.exists?(state, Model.RevOrigin, {122, :contract_call_tx, <<2::256>>})
      assert State.exists?(state, Model.RevOrigin, {123, :ga_attach_tx, <<3::256>>})

      assert State.exists?(state, Model.Field, {:contract_create_tx, nil, <<1::256>>, 121})
      assert State.exists?(state, Model.Field, {:contract_call_tx, nil, <<2::256>>, 122})
      assert State.exists?(state, Model.Field, {:ga_attach_tx, nil, <<3::256>>, 123})

      assert ObjectKeys.count_contracts(state) == 3
    end
  end
end

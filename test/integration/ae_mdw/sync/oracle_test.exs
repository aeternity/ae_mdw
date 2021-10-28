defmodule Integration.AeMdw.Db.Sync.OracleTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync
  alias AeMdw.Db.Util

  require Model

  describe "extend" do
    test "succeeds when oracle is active" do
      fn ->
        {_height, pubkey} = Util.last(Model.ActiveOracleExpiration)
        tx = new_oracle_extend_tx(pubkey)

        assert Sync.Oracle.extend(
                 pubkey,
                 tx,
                 Util.last_txi(),
                 {Sync.height(:top), 0}
               )

        :mnesia.abort(:rollback)
      end
      |> :mnesia.transaction()
      |> case do
        {:aborted, {%ExUnit.AssertionError{} = assertion_error, _stacktrace}} ->
          raise assertion_error

        {:aborted, :rollback} ->
          :pass

        other_result ->
          throw(other_result)
      end
    end

    test "fails when oracle is not active" do
      fn ->
        {_height, pubkey} = Util.last(Model.InactiveOracleExpiration)
        tx = new_oracle_extend_tx(pubkey)

        refute Sync.Oracle.extend(
                 pubkey,
                 tx,
                 Util.last_txi(),
                 {Sync.height(:top), 0}
               )

        :mnesia.abort(:rollback)
      end
      |> :mnesia.transaction()
      |> case do
        {:aborted, {%ExUnit.AssertionError{} = assertion_error, _stacktrace}} ->
          raise assertion_error

        {:aborted, :rollback} ->
          :pass

        other_result ->
          throw(other_result)
      end
    end
  end

  defp new_oracle_extend_tx(pubkey) do
    {:ok, tx_rec} =
      :aeo_extend_tx.new(%{
        oracle_id: :aeser_id.create(:oracle, pubkey),
        nonce: 1,
        oracle_ttl: {:delta, 100},
        fee: 1_000_000_000
      })

    {_mod, tx} = :aetx.specialize_callback(tx_rec)
    tx
  end
end

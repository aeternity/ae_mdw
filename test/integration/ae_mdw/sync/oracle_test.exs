defmodule Integration.AeMdw.Db.Sync.OracleTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.Sync
  alias AeMdw.Db.Util

  require Model

  import Support.TestMnesiaSandbox

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
      |> mnesia_sandbox()
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
      |> mnesia_sandbox()
    end
  end

  describe "expire/1" do
    test "inactivates an oracle that has just expired" do
      {height, pubkey} = Util.last(Model.ActiveOracleExpiration)
      mutation = Oracle.expirations_mutation(height)

      fn ->
        m_oracle = Util.read!(Model.ActiveOracle, pubkey)

        Mutation.mutate(mutation)

        assert [Model.expiration(index: {height, pubkey})] ==
                 Util.read(Model.InactiveOracleExpiration, {height, pubkey})

        assert [m_oracle] == Util.read(Model.InactiveOracle, pubkey)

        :mnesia.abort(:rollback)
      end
      |> mnesia_sandbox()
    end

    test "does nothing when oracle has multiple expirations and last one is greater than height" do
      fn ->
        {height, pubkey} = Util.last(Model.ActiveOracleExpiration)
        m_oracle = Util.read!(Model.ActiveOracle, pubkey)

        m_old_exp = Model.expiration(index: {height - 1, pubkey})
        :mnesia.write(Model.ActiveOracleExpiration, m_old_exp, :write)

        (height - 1)
        |> Oracle.expirations_mutation()
        |> Mutation.mutate()

        assert {height, pubkey} == Util.last(Model.ActiveOracleExpiration)
        assert [m_oracle] == Util.read(Model.ActiveOracle, pubkey)

        :mnesia.abort(:rollback)
      end
      |> mnesia_sandbox()
    end

    test "does nothing when oracle has not yet expired" do
      fn ->
        {height, pubkey} = Util.last(Model.ActiveOracleExpiration)
        m_oracle = Util.read!(Model.ActiveOracle, pubkey)

        (height - 1)
        |> Oracle.expirations_mutation()
        |> Mutation.mutate()

        assert {height, pubkey} == Util.last(Model.ActiveOracleExpiration)
        assert [m_oracle] == Util.read(Model.ActiveOracle, pubkey)

        :mnesia.abort(:rollback)
      end
      |> mnesia_sandbox()
    end

    test "does nothing when oracle is already inactive" do
      fn ->
        {height, pubkey} = Util.last(Model.InactiveOracleExpiration)
        m_oracle = Util.read!(Model.InactiveOracle, pubkey)

        height
        |> Oracle.expirations_mutation()
        |> Mutation.mutate()

        assert {height, pubkey} == Util.last(Model.InactiveOracleExpiration)
        assert [m_oracle] == Util.read(Model.InactiveOracle, pubkey)

        :mnesia.abort(:rollback)
      end
      |> mnesia_sandbox()
    end
  end

  #
  # Helper functions
  #
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

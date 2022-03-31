defmodule AeMdw.Db.Sync.OracleTest do
  use ExUnit.Case, async: false

  alias AeMdw.Db.Model
  alias AeMdw.Db.OracleExtendMutation
  alias AeMdw.Db.OraclesExpirationMutation
  alias AeMdw.Db.Util
  alias AeMdw.Database

  require Model

  @pubkey1 <<123_451::256>>
  @pubkey2 <<123_452::256>>
  @pubkey3 <<123_453::256>>
  @pubkey4 <<123_454::256>>
  @pubkey5 <<123_455::256>>

  @sync_height 1000
  @expire1 999
  @expire2 1000
  @expire3 1001
  @expire4 1001
  @expire5 1001

  setup_all %{} do
    last_txi = 1234

    [
      Model.oracle(
        index: @pubkey1,
        expire: @expire1,
        register: {{898, 0}, last_txi},
        extends: nil,
        previous: nil
      )
    ]
    |> Enum.each(&Database.dirty_write(Model.InactiveOracle, &1))

    [
      Model.expiration(index: {@expire1, @pubkey1})
    ]
    |> Enum.each(&Database.dirty_write(Model.InactiveOracleExpiration, &1))

    [
      Model.oracle(
        index: @pubkey3,
        expire: @expire3,
        register: {{900, 0}, last_txi + 2},
        extends: nil,
        previous: nil
      ),
      Model.oracle(
        index: @pubkey4,
        expire: @expire4,
        register: {{900, 0}, last_txi + 3},
        extends: nil,
        previous: nil
      ),
      Model.oracle(
        index: @pubkey5,
        expire: @expire5,
        register: {{999, 0}, last_txi + 4},
        extends: nil,
        previous: nil
      )
    ]
    |> Enum.each(&Database.dirty_write(Model.ActiveOracle, &1))

    [
      Model.expiration(index: {@expire3, @pubkey3}),
      Model.expiration(index: {@expire4, @pubkey4}),
      Model.expiration(index: {@sync_height - 1, @pubkey4}),
      Model.expiration(index: {@expire5, @pubkey5})
    ]
    |> Enum.each(&Database.dirty_write(Model.ActiveOracleExpiration, &1))

    :ok
  end

  describe "extend" do
    test "fails when oracle is not active" do
      mutation =
        OracleExtendMutation.new(
          {@sync_height, 0},
          1234,
          @pubkey1,
          123
        )

      Database.commit([mutation])

      assert :not_found = Database.fetch(Model.ActiveOracle, @pubkey1)

      pubkey = @pubkey1
      expire = @expire1

      assert Model.oracle(index: ^pubkey, expire: ^expire) =
               Database.fetch!(Model.InactiveOracle, @pubkey1)

      assert Model.expiration(index: {^expire, ^pubkey}) =
               Database.fetch!(Model.InactiveOracleExpiration, {expire, pubkey})
    end

    test "succeeds when oracle is active" do
      ttl = 123
      pubkey = @pubkey3
      new_expiration = @expire3 + ttl

      mutation =
        OracleExtendMutation.new(
          {@sync_height, 0},
          1234,
          pubkey,
          ttl
        )

      Database.commit([mutation])

      assert Model.oracle(index: ^pubkey, expire: ^new_expiration) =
               Database.fetch!(Model.ActiveOracle, pubkey)

      assert Model.expiration(index: {^new_expiration, ^pubkey}) =
               Database.fetch!(Model.ActiveOracleExpiration, {new_expiration, pubkey})

      assert :not_found = Database.fetch(Model.ActiveOracleExpiration, {@expire3, pubkey})
    end
  end

  describe "expire/1" do
    test "inactivates an oracle that has just expired" do
      assert @expire2 == @sync_height
      m_exp = Model.expiration(index: {@expire2, @pubkey2})
      Database.dirty_write(Model.ActiveOracleExpiration, m_exp)

      m_oracle =
        Model.oracle(
          index: @pubkey2,
          expire: @expire2,
          register: {{899, 0}, 1234},
          extends: nil,
          previous: nil
        )

      Database.dirty_write(Model.ActiveOracle, m_oracle)

      pubkey = @pubkey2
      sync_height = @sync_height
      mutation = OraclesExpirationMutation.new(sync_height)
      Database.commit([mutation])

      assert :not_found = Database.fetch(Model.ActiveOracleExpiration, {sync_height, pubkey})

      assert Model.expiration(index: {^sync_height, ^pubkey}) =
               Database.fetch!(Model.InactiveOracleExpiration, {sync_height, pubkey})
    end

    test "does nothing when oracle has multiple expirations and last one is greater than height" do
      pubkey = @pubkey4
      m_oracle = Util.read!(Model.ActiveOracle, pubkey)

      mutation = OraclesExpirationMutation.new(@sync_height)
      Database.commit([mutation])

      assert Model.expiration(index: {@expire4, pubkey}) ==
               Database.fetch!(Model.ActiveOracleExpiration, {@expire4, pubkey})

      assert [m_oracle] == Util.read(Model.ActiveOracle, pubkey)
    end

    test "does nothing when oracle has not yet expired" do
      pubkey = @pubkey5
      assert Model.oracle(expire: expire) = m_oracle = Util.read!(Model.ActiveOracle, pubkey)
      assert expire == @expire5
      assert expire > @sync_height

      mutation = OraclesExpirationMutation.new(@sync_height)
      Database.commit([mutation])

      assert Model.expiration(index: {@expire5, pubkey}) ==
               Database.fetch!(Model.ActiveOracleExpiration, {@expire5, pubkey})

      assert [m_oracle] == Util.read(Model.ActiveOracle, pubkey)
    end

    test "does nothing when oracle is already inactive" do
      pubkey = @pubkey1
      assert :not_found = Database.fetch(Model.ActiveOracle, @pubkey1)
      assert m_oracle = Util.read!(Model.InactiveOracle, pubkey)

      mutation = OraclesExpirationMutation.new(@sync_height)
      Database.commit([mutation])

      assert Model.expiration(index: {@expire1, pubkey}) ==
               Database.fetch!(Model.InactiveOracleExpiration, {@expire1, pubkey})

      assert [m_oracle] == Util.read(Model.InactiveOracle, pubkey)
    end
  end
end

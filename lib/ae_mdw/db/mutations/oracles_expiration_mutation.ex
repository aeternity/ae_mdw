defmodule AeMdw.Db.OraclesExpirationMutation do
  @moduledoc """
  Deactivate all Oracles that have expired on a block height.

  The expiration height of an Oracle is always a result of the last `register`
   or `extend` operation.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Log

  import AeMdw.Db.Oracle, only: [cache_through_read: 3]

  import AeMdw.Db.Sync.Oracle,
    only: [
      cache_through_delete: 3,
      cache_through_write: 3
    ]

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:height]

  @opaque t() :: %__MODULE__{
            height: Blocks.height()
          }

  @spec new(Blocks.height()) :: t()
  def new(height), do: %__MODULE__{height: height}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{height: height}, state) do
    state
    |> Collection.stream(Model.ActiveOracleExpiration, {height, <<>>})
    |> Stream.take_while(&match?({^height, _pk}, &1))
    |> Enum.to_list()
    |> Enum.reduce(state, fn {^height, pubkey}, state ->
      expire_oracle(state, height, pubkey)
    end)
  end

  defp expire_oracle(state, height, pubkey) do
    oracle_id = Enc.encode(:oracle_pubkey, pubkey)
    state2 = cache_through_delete(state, Model.ActiveOracleExpiration, {height, pubkey})

    case cache_through_read(state2, Model.ActiveOracle, pubkey) do
      {:ok, m_oracle} ->
        if height == Model.oracle(m_oracle, :expire) do
          m_exp = Model.expiration(index: {height, pubkey})

          Log.info("[#{height}] inactivated oracle #{oracle_id}")

          state2
          |> cache_through_write(Model.InactiveOracle, m_oracle)
          |> cache_through_write(Model.InactiveOracleExpiration, m_exp)
          |> cache_through_delete(Model.ActiveOracle, pubkey)
          |> State.inc_stat(:oracles_expired)
        else
          Log.warn("[#{height}] ignored old oracle expiration for #{oracle_id}")
          state2
        end

      nil ->
        Log.warn("[#{height}] ignored oracle expiration for #{oracle_id}")
        state2
    end
  end
end

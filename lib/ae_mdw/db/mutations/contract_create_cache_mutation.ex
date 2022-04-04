defmodule AeMdw.Db.ContractCreateCacheMutation do
  @moduledoc """
  Adds a contract creation pk to the cache and increases the
  `:contracts_created` stat.
  """

  alias AeMdw.Db.State
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  @derive AeMdw.Db.Mutation
  defstruct [:contract_pk, :txi]

  @opaque t() :: %__MODULE__{
            txi: Txs.txi(),
            contract_pk: Db.pubkey()
          }

  @spec new(Db.pubkey(), Txs.txi()) :: t()
  def new(contract_pk, txi) do
    %__MODULE__{contract_pk: contract_pk, txi: txi}
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{contract_pk: contract_pk, txi: txi}, state) do
    state
    |> State.cache_put(:ct_create_sync_cache, contract_pk, txi)
    |> State.inc_stat(:contracts_created)
  end
end

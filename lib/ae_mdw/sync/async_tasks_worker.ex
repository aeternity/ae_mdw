defmodule AeMdw.Sync.AsyncTasksWorker do
  @moduledoc """
  Database synchronization tasks that might run asynchronously.
  """
  use GenServer

  alias AeMdw.Db.Contract
  alias AeMdw.Node.Db, as: DBN

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    {:ok, []}
  end

  @doc """
  Updates the presence/mapping of accounts that have balance in a Aex9 contract.
  """
  def handle_call({:update_aex9_presence, [contract_pk, delete_account_pk]}, _from, state) do
    # update account to aex9 contract mapping for all accounts with balance
    {amounts, _last_block_tuple} = DBN.aex9_balances(contract_pk)

    Enum.each(amounts, fn {{:address, account_pk}, _amount} ->
      if account_pk == delete_account_pk do
        Contract.aex9_delete_presence(contract_pk, -1, delete_account_pk)
      else
        Contract.aex9_write_new_presence(contract_pk, -1, account_pk)
      end
    end)

    {:reply, :ok, state}
  end
end

defmodule AeMdw.Sync.AsyncTasks.Consumer do
  @moduledoc """
  Synchronization tasks that run asynchronously consuming Model.AsyncTasks records.
  """
  use GenServer

  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Node.Db, as: DBN
  alias AeMdw.Sync.AsyncTasks.Producer

  require Model

  @base_sleep_msecs 700

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok)
  end

  @impl GenServer
  def init(:ok) do
    {:ok, %{}, {:continue, :demand}}
  end

  @impl GenServer
  def handle_continue(:demand, _state) do
    demand()
  end

  @impl GenServer
  def handle_info(:demand, _state) do
    demand()
  end

  #
  # Private functions
  #
  defp demand() do
    m_task = Producer.dequeue()

    if nil != m_task do
      process(m_task)
      Model.async_tasks(index: index) = m_task
      Producer.notify_consumed(index)
      {:noreply, %{}, {:continue, :demand}}
    else
      Process.send_after(self(), :demand, sleep_msecs())
      {:noreply, %{}}
    end
  end

  # Updates the presence/mapping of accounts that have balance in a Aex9 contract
  defp process(
         Model.async_tasks(
           index: {_ts, :update_aex9_presence},
           args: [contract_pk, delete_account_pk]
         )
       ) do
    {amounts, _last_block_tuple} = DBN.aex9_balances(contract_pk)

    Enum.each(amounts, fn {{:address, account_pk}, _amount} ->
      if account_pk == delete_account_pk do
        Contract.aex9_delete_presence(contract_pk, -1, delete_account_pk)
      else
        Contract.aex9_write_new_presence(contract_pk, -1, account_pk)
      end
    end)
  end

  defp sleep_msecs(), do: @base_sleep_msecs + Enum.random(-200..200)
end

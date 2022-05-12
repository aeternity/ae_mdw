defmodule AeMdw.Db.Contract do
  @moduledoc """
  Data access to read and write Contract related models.
  """
  alias AeMdw.Collection
  alias AeMdw.Contract
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.Sync
  alias AeMdw.Db.State
  alias AeMdw.Log
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Validate

  require Ex2ms
  require Log
  require Model
  require Record

  import AeMdw.Util, only: [compose: 2, min_bin: 0, max_256bit_bin: 0, max_256bit_int: 0]
  import AeMdw.Db.Util

  @type rev_aex9_contract_key :: {pos_integer(), String.t(), String.t(), pos_integer()}
  @typep pubkey :: Db.pubkey()
  @typep state() :: State.t()

  @spec aex9_creation_write(state(), tuple(), pubkey(), integer()) :: state()
  def aex9_creation_write(state, {name, symbol, decimals}, contract_pk, txi) do
    m_contract = Model.aex9_contract(index: {name, symbol, txi, decimals})
    m_contract_sym = Model.aex9_contract_symbol(index: {symbol, name, txi, decimals})
    m_rev_contract = Model.rev_aex9_contract(index: {txi, name, symbol, decimals})
    m_contract_pk = Model.aex9_contract_pubkey(index: contract_pk, txi: txi)

    state
    |> State.put(Model.Aex9Contract, m_contract)
    |> State.put(Model.Aex9ContractSymbol, m_contract_sym)
    |> State.put(Model.RevAex9Contract, m_rev_contract)
    |> State.put(Model.Aex9ContractPubkey, m_contract_pk)
  end

  @spec aex9_write_presence(pubkey(), integer(), pubkey()) :: :ok
  def aex9_write_presence(contract_pk, txi, pubkey) do
    m_acc_presence = Model.aex9_account_presence(index: {pubkey, txi, contract_pk})
    m_idx_presence = Model.idx_aex9_account_presence(index: {txi, pubkey, contract_pk})

    Database.dirty_write(Model.Aex9AccountPresence, m_acc_presence)
    Database.dirty_write(Model.IdxAex9AccountPresence, m_idx_presence)
  end

  @spec aex9_write_new_presence(pubkey(), integer(), pubkey()) :: boolean()
  def aex9_write_new_presence(contract_pk, txi, account_pk) do
    if aex9_presence_exists?(contract_pk, account_pk, txi) do
      false
    else
      aex9_write_presence(contract_pk, txi, account_pk)
      true
    end
  end

  @spec aex9_burn_balance(state(), pubkey(), pubkey(), non_neg_integer()) :: state()
  def aex9_burn_balance(state, contract_pk, account_pk, burned_value) do
    aex9_update_balance(state, contract_pk, account_pk, fn amount -> amount - burned_value end)
  end

  @spec aex9_swap_balance(state(), pubkey(), pubkey()) :: state()
  def aex9_swap_balance(state, contract_pk, caller_pk) do
    aex9_update_balance(state, contract_pk, caller_pk, fn _any -> 0 end)
  end

  @spec aex9_mint_balance(state(), pubkey(), pubkey(), non_neg_integer()) :: state()
  def aex9_mint_balance(state, contract_pk, to_pk, minted_value) do
    aex9_update_balance(state, contract_pk, to_pk, fn amount -> amount + minted_value end)
  end

  @spec aex9_transfer_balance(state(), pubkey(), pubkey(), pubkey(), non_neg_integer()) :: state()
  def aex9_transfer_balance(state, contract_pk, from_pk, to_pk, transfered_value) do
    case State.get(state, Model.Aex9Balance, {contract_pk, from_pk}) do
      {:ok, m_aex9_balance_from} ->
        m_aex9_balance_to = fetch_aex9_balance_or_new(state, contract_pk, to_pk)
        from_amount = Model.aex9_balance(m_aex9_balance_from, :amount)
        to_amount = Model.aex9_balance(m_aex9_balance_to, :amount)

        m_aex9_balance_from =
          Model.aex9_balance(m_aex9_balance_from, amount: from_amount - transfered_value)

        m_aex9_balance_to =
          Model.aex9_balance(m_aex9_balance_to, amount: to_amount + transfered_value)

        state
        |> State.put(Model.Aex9Balance, m_aex9_balance_from)
        |> State.put(Model.Aex9Balance, m_aex9_balance_to)

      :not_found ->
        state
    end
  end

  @spec aex9_delete_balances(state(), pubkey()) :: state()
  def aex9_delete_balances(state, contract_pk) do
    state
    |> Collection.stream(
      Model.Aex9Balance,
      :forward,
      {{contract_pk, min_bin()}, {contract_pk, max_256bit_bin()}},
      nil
    )
    |> Enum.reduce(state, fn {contract_pk, account_pk}, state ->
      State.delete(state, Model.Aex9Balance, {contract_pk, account_pk})
    end)
  end

  @spec aex9_presence_exists?(pubkey(), pubkey(), integer()) :: boolean()
  def aex9_presence_exists?(contract_pk, account_pk, txi) do
    txi_search_prev = txi + 1

    case Database.prev_key(
           Model.Aex9AccountPresence,
           {account_pk, txi_search_prev, contract_pk}
         ) do
      {:ok, {^account_pk, _txi, ^contract_pk}} -> true
      _none_or_other_key -> false
    end
  end

  @spec call_write(state(), integer(), integer(), Contract.fun_arg_res_or_error()) :: state()
  def call_write(state, create_txi, txi, %{
        function: fname,
        arguments: args,
        result: %{error: [err]}
      }),
      do: call_write(state, create_txi, txi, fname, args, :error, err)

  def call_write(state, create_txi, txi, %{
        function: fname,
        arguments: args,
        result: %{abort: [err]}
      }),
      do: call_write(state, create_txi, txi, fname, args, :abort, err)

  def call_write(state, create_txi, txi, %{function: fname, arguments: args, result: val}),
    do: call_write(state, create_txi, txi, fname, args, :ok, val)

  def call_write(state, create_txi, txi, {:error, detail}),
    do: call_write(state, create_txi, txi, "<unknown>", nil, :invalid, inspect(detail))

  @spec call_write(state(), Txs.txi(), Txs.txi(), String.t(), list() | nil, any(), any()) ::
          state()
  def call_write(state, create_txi, txi, fname, args, result, return) do
    m_call =
      Model.contract_call(
        index: {create_txi, txi},
        fun: fname,
        args: args,
        result: result,
        return: return
      )

    State.put(state, Model.ContractCall, m_call)
  end

  @spec logs_write(state(), Txs.txi(), Txs.txi(), tuple()) :: state()
  def logs_write(state, create_txi, txi, call_rec) do
    contract_pk = :aect_call.contract_pubkey(call_rec)
    raw_logs = :aect_call.log(call_rec)

    raw_logs
    |> Enum.with_index()
    |> Enum.reduce(state, fn {{addr, [evt_hash | args], data}, i}, state ->
      m_log =
        Model.contract_log(
          index: {create_txi, txi, evt_hash, i},
          ext_contract: (addr == contract_pk && nil) || addr,
          args: args,
          data: data
        )

      m_data_log = Model.data_contract_log(index: {data, txi, create_txi, evt_hash, i})
      m_evt_log = Model.evt_contract_log(index: {evt_hash, txi, create_txi, i})
      m_idx_log = Model.idx_contract_log(index: {txi, create_txi, evt_hash, i})

      state2 =
        state
        |> State.put(Model.ContractLog, m_log)
        |> State.put(Model.DataContractLog, m_data_log)
        |> State.put(Model.EvtContractLog, m_evt_log)
        |> State.put(Model.IdxContractLog, m_idx_log)

      # if remote call then indexes also with the called contract
      state3 =
        if addr != contract_pk do
          {remote_called_contract_txi, state3} = Sync.Contract.get_txi!(state2, addr)

          # on caller log: ext_contract = called contract_pk
          # on called log: ext_contract = {:parent_contract_pk, caller contract_pk}
          m_log_remote =
            Model.contract_log(
              index: {remote_called_contract_txi, txi, evt_hash, i},
              ext_contract: {:parent_contract_pk, contract_pk},
              args: args,
              data: data
            )

          State.put(state3, Model.ContractLog, m_log_remote)
        else
          state2
        end

      aex9_contract_pk = which_aex9_contract_pubkey(contract_pk, addr)

      if is_aex9_transfer?(evt_hash, aex9_contract_pk) do
        write_aex9_records(state3, aex9_contract_pk, txi, i, args)
      else
        state3
      end
    end)
  end

  @spec is_aex9_transfer?(binary(), pubkey()) :: boolean()
  def is_aex9_transfer?(evt_hash, aex9_contract_pk) do
    aex9_transfer_evt = Node.aex9_transfer_event_hash()

    evt_hash == aex9_transfer_evt and aex9_contract_pk != nil
  end

  @spec which_aex9_contract_pubkey(pubkey(), pubkey()) :: pubkey() | nil
  def which_aex9_contract_pubkey(contract_pk, addr) do
    if Contract.is_aex9?(contract_pk) do
      contract_pk
    else
      # remotely called contract is aex9?
      if addr != contract_pk and Contract.is_aex9?(addr), do: addr
    end
  end

  @spec call_fun_arg_res(pubkey(), integer()) :: Contract.fun_arg_res()
  def call_fun_arg_res(contract_pk, call_txi) do
    create_txi = Origin.tx_index!({:contract, contract_pk})
    m_call = read!(Model.ContractCall, {create_txi, call_txi})

    %{
      function: Model.contract_call(m_call, :fun),
      arguments: Model.contract_call(m_call, :args),
      result: Model.contract_call(m_call, :result),
      return: Model.contract_call(m_call, :return)
    }
  end

  @spec aex9_search_name(tuple()) :: map()
  def aex9_search_name({_, _} = mode),
    do: aex9_search_tokens(Model.Aex9Contract, mode)

  @spec aex9_search_symbol(tuple()) :: map()
  def aex9_search_symbol({_, _} = mode),
    do: aex9_search_tokens(Model.Aex9ContractSymbol, mode)

  @spec aex9_search_contract_by_id(String.t()) :: {:ok, rev_aex9_contract_key()} | :not_found
  def aex9_search_contract_by_id(contract_id) do
    with pubkey <- Validate.id!(contract_id),
         {:ok, txi} <- AeMdw.Db.Origin.tx_index({:contract, pubkey}) do
      {:ok, {^txi, _name, _symbol, _decimals} = rev_aex9_key} =
        Database.next_key(Model.RevAex9Contract, {txi, nil, nil, nil})

      {:ok, rev_aex9_key}
    end
  end

  @spec aex9_search_tokens(atom(), tuple()) :: map()
  def aex9_search_tokens(table, {:prefix, prefix}),
    do: aex9_search_tokens(table, prefix, prefix_tester(prefix))

  def aex9_search_tokens(table, {:exact, exact}),
    do: aex9_search_tokens(table, exact, &(&1 == exact))

  @spec aex9_search_tokens(atom(), any(), any()) :: map()
  def aex9_search_tokens(table, value, key_tester) do
    gen_collect(
      table,
      {value, "", 0, 0},
      compose(key_tester, &elem(&1, 0)),
      &next/2,
      fn -> [] end,
      fn v, l -> [v | l] end,
      &Enum.reverse/1
    )
  end

  @spec aex9_search_transfers(
          {:from, pubkey()}
          | {:to, pubkey()}
          | {:from_to, pubkey(), pubkey()}
        ) :: Enumerable.t()
  def aex9_search_transfers({:from, sender_pk}) do
    aex9_search_transfers(Model.Aex9Transfer, {sender_pk, -1, nil, -1, -1}, fn key ->
      elem(key, 0) == sender_pk
    end)
  end

  def aex9_search_transfers({:to, recipient_pk}) do
    aex9_search_transfers(Model.RevAex9Transfer, {recipient_pk, -1, nil, -1, -1}, fn key ->
      elem(key, 0) == recipient_pk
    end)
  end

  def aex9_search_transfers({:from_to, sender_pk, recipient_pk}) do
    aex9_search_transfers(
      Model.Aex9PairTransfer,
      {sender_pk, recipient_pk, -1, -1, -1},
      fn key -> elem(key, 0) == sender_pk && elem(key, 1) == recipient_pk end
    )
  end

  @spec aex9_search_contracts(pubkey()) :: [pubkey()]
  def aex9_search_contracts(account_pk) do
    Model.Aex9AccountPresence
    |> Collection.stream({account_pk, -1, <<>>})
    |> Stream.take_while(fn {apk, _txi, _ct_pk} -> apk == account_pk end)
    |> Enum.map(fn {_apk, _txi, contract_pk} -> contract_pk end)
  end

  @spec aex9_search_contract(pubkey(), integer()) :: map()
  def aex9_search_contract(account_pk, last_txi) do
    gen_collect(
      Model.Aex9AccountPresence,
      {account_pk, last_txi, <<max_256bit_int()::256>>},
      fn {acc_pk, _, _} -> acc_pk == account_pk end,
      &prev/2,
      fn -> %{} end,
      fn {_, txi, ct_pk}, accum ->
        Map.update(accum, ct_pk, [txi], fn txi_list ->
          [txi | txi_list]
        end)
      end,
      & &1
    )
  end

  #
  # Private functions
  #
  defp aex9_search_transfers(table, init_key, key_tester) do
    table
    |> Collection.stream(init_key)
    |> Stream.take_while(key_tester)
  end

  defp aex9_update_balance(state, contract_pk, account_pk, new_amount_fn) do
    case State.get(state, Model.Aex9Balance, {contract_pk, account_pk}) do
      {:ok, Model.aex9_balance(amount: old_amount) = m_aex9_balance} ->
        m_aex9_balance = Model.aex9_balance(m_aex9_balance, amount: new_amount_fn.(old_amount))
        State.put(state, Model.Aex9Balance, m_aex9_balance)

      :not_found ->
        state
    end
  end

  defp prefix_tester(""),
    do: fn _any -> true end

  defp prefix_tester(prefix) do
    len = byte_size(prefix)
    &(byte_size(&1) >= len && :binary.part(&1, 0, len) == prefix)
  end

  defp write_aex9_records(state, contract_pk, txi, i, [from_pk, to_pk, <<amount::256>>]) do
    m_transfer = Model.aex9_transfer(index: {from_pk, txi, to_pk, amount, i})
    m_rev_transfer = Model.rev_aex9_transfer(index: {to_pk, txi, from_pk, amount, i})
    m_idx_transfer = Model.idx_aex9_transfer(index: {txi, i, from_pk, to_pk, amount})
    m_pair_transfer = Model.aex9_pair_transfer(index: {from_pk, to_pk, txi, amount, i})

    aex9_write_presence(contract_pk, txi, to_pk)

    state
    |> State.put(Model.Aex9Transfer, m_transfer)
    |> State.put(Model.RevAex9Transfer, m_rev_transfer)
    |> State.put(Model.IdxAex9Transfer, m_idx_transfer)
    |> State.put(Model.Aex9PairTransfer, m_pair_transfer)
  end

  defp fetch_aex9_balance_or_new(state, contract_pk, account_pk) do
    case State.get(state, Model.Aex9Balance, {contract_pk, account_pk}) do
      {:ok, m_balance} -> m_balance
      :not_found -> Model.aex9_balance(index: {contract_pk, account_pk}, amount: 0)
    end
  end
end

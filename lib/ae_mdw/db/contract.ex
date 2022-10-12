defmodule AeMdw.Db.Contract do
  @moduledoc """
  Data access to read and write Contract related models.
  """

  alias AeMdw.AexnContracts
  alias AeMdw.Collection
  alias AeMdw.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Log
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Db.Sync.Stats, as: SyncStats

  require Ex2ms
  require Log
  require Model
  require Record

  import AeMdwWeb.Helpers.AexnHelper, only: [sort_field_truncate: 1]

  @type rev_aex9_contract_key :: {pos_integer(), String.t(), String.t(), pos_integer()}
  @typep hash :: <<_::256>>
  @typep pubkey :: Db.pubkey()
  @typep state :: State.t()
  @typep block_index :: AeMdw.Blocks.block_index()
  @typep txi :: AeMdw.Txs.txi()
  @typep log_idx :: AeMdw.Contracts.log_idx()

  @spec aexn_creation_write(
          state(),
          Model.aexn_type(),
          Model.aexn_meta_info(),
          pubkey(),
          integer(),
          Model.aexn_extensions()
        ) :: state()
  def aexn_creation_write(state, aexn_type, aexn_meta_info, contract_pk, txi, extensions) do
    m_contract_pk =
      Model.aexn_contract(
        index: {aexn_type, contract_pk},
        txi: txi,
        meta_info: aexn_meta_info,
        extensions: extensions
      )

    state2 = State.put(state, Model.AexnContract, m_contract_pk)

    name = elem(aexn_meta_info, 0)
    symbol = elem(aexn_meta_info, 1)

    if name == :out_of_gas_error do
      state2
    else
      m_contract_name =
        Model.aexn_contract_name(index: {aexn_type, sort_field_truncate(name), contract_pk})

      m_contract_sym =
        Model.aexn_contract_symbol(index: {aexn_type, sort_field_truncate(symbol), contract_pk})

      state2
      |> State.put(Model.AexnContractName, m_contract_name)
      |> State.put(Model.AexnContractSymbol, m_contract_sym)
    end
  end

  @spec aex9_write_presence(state(), pubkey(), integer(), pubkey()) :: state()
  def aex9_write_presence(state, contract_pk, txi, account_pk) do
    m_acc_presence = Model.aex9_account_presence(index: {account_pk, contract_pk}, txi: txi)

    State.put(state, Model.Aex9AccountPresence, m_acc_presence)
  end

  @spec aex9_delete_presence(state(), pubkey(), pubkey()) :: state()
  def aex9_delete_presence(state, account_pk, contract_pk) do
    if State.exists?(state, Model.Aex9AccountPresence, {account_pk, contract_pk}) do
      State.delete(state, Model.Aex9AccountPresence, {account_pk, contract_pk})
    else
      state
    end
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

  @spec call_write(state(), txi(), txi(), String.t(), list() | nil, any(), any()) ::
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

  @spec logs_write(state(), block_index(), txi(), txi(), Contract.call()) :: state()
  def logs_write(state, block_index, create_txi, txi, call_rec) do
    contract_pk = :aect_call.contract_pubkey(call_rec)
    raw_logs = :aect_call.log(call_rec)

    raw_logs
    |> Enum.with_index()
    |> Enum.reduce(state, fn {{addr, [evt_hash | args], data}, log_idx} = log, state ->
      m_log =
        Model.contract_log(
          index: {create_txi, txi, evt_hash, log_idx},
          ext_contract: (addr != contract_pk && addr) || nil,
          args: args,
          data: data
        )

      m_data_log = Model.data_contract_log(index: {data, txi, create_txi, evt_hash, log_idx})
      m_evt_log = Model.evt_contract_log(index: {evt_hash, txi, create_txi, log_idx})
      m_idx_log = Model.idx_contract_log(index: {txi, log_idx, create_txi, evt_hash})

      state2 =
        state
        |> State.put(Model.ContractLog, m_log)
        |> State.put(Model.DataContractLog, m_data_log)
        |> State.put(Model.EvtContractLog, m_evt_log)
        |> State.put(Model.IdxContractLog, m_idx_log)
        |> maybe_index_remote_log(contract_pk, block_index, txi, log)

      aex9_contract_pk = which_aex9_contract_pubkey(contract_pk, addr)

      cond do
        is_aexn_transfer?(evt_hash) and aex9_contract_pk != nil ->
          write_aexn_transfer(state2, :aex9, aex9_contract_pk, txi, log_idx, args)

        State.exists?(state2, Model.AexnContract, {:aex141, addr}) ->
          write_aex141_records(state2, evt_hash, addr, txi, log_idx, args)

        true ->
          state2
      end
    end)
  end

  @spec is_aexn_transfer?(binary()) :: boolean()
  def is_aexn_transfer?(evt_hash) do
    evt_hash == Node.aexn_transfer_event_hash()
  end

  @spec which_aex9_contract_pubkey(pubkey(), pubkey()) :: pubkey() | nil
  def which_aex9_contract_pubkey(contract_pk, addr) do
    if AexnContracts.is_aex9?(contract_pk) do
      contract_pk
    else
      # remotely called contract is aex9?
      if addr != contract_pk and AexnContracts.is_aex9?(addr), do: addr
    end
  end

  @spec call_fun_arg_res(State.t(), pubkey(), integer()) :: Contract.fun_arg_res()
  def call_fun_arg_res(state, contract_pk, call_txi) do
    create_txi = Origin.tx_index!(state, {:contract, contract_pk})
    m_call = State.fetch!(state, Model.ContractCall, {create_txi, call_txi})

    %{
      function: Model.contract_call(m_call, :fun),
      arguments: Model.contract_call(m_call, :args),
      result: Model.contract_call(m_call, :result),
      return: Model.contract_call(m_call, :return)
    }
  end

  @spec aex9_search_transfers(
          State.t(),
          {:from, pubkey()}
          | {:to, pubkey()}
          | {:from_to, pubkey(), pubkey()}
        ) :: Enumerable.t()
  def aex9_search_transfers(state, {:from, sender_pk}) do
    aex9_search_transfers(
      state,
      Model.AexnTransfer,
      {:aex9, sender_pk, -1, nil, -1, -1},
      fn key ->
        elem(key, 0) == :aex9 and elem(key, 1) == sender_pk
      end
    )
  end

  def aex9_search_transfers(state, {:to, recipient_pk}) do
    aex9_search_transfers(
      state,
      Model.RevAexnTransfer,
      {:aex9, recipient_pk, -1, nil, -1, -1},
      fn key ->
        elem(key, 0) == :aex9 and elem(key, 1) == recipient_pk
      end
    )
  end

  def aex9_search_transfers(state, {:from_to, sender_pk, recipient_pk}) do
    aex9_search_transfers(
      state,
      Model.AexnPairTransfer,
      {:aex9, sender_pk, recipient_pk, -1, -1, -1},
      fn key ->
        elem(key, 0) == :aex9 and elem(key, 1) == sender_pk && elem(key, 2) == recipient_pk
      end
    )
  end

  @spec aex9_search_contracts(State.t(), pubkey()) :: [pubkey()]
  def aex9_search_contracts(state, account_pk) do
    state
    |> Collection.stream(Model.Aex9AccountPresence, {account_pk, <<>>})
    |> Stream.take_while(fn {apk, _ct_pk} -> apk == account_pk end)
    |> Enum.map(fn {_apk, contract_pk} -> contract_pk end)
  end

  @spec aex9_search_contract(State.t(), pubkey(), integer()) :: map()
  def aex9_search_contract(state, account_pk, max_txi) do
    state
    |> Collection.stream(Model.Aex9AccountPresence, {account_pk, <<>>})
    |> Stream.take_while(fn {apk, _ct_pk} -> apk == account_pk end)
    |> Enum.reduce(%{}, fn {_apk, contract_pk} = key, acc ->
      Model.aex9_account_presence(txi: txi) = State.fetch!(state, Model.Aex9AccountPresence, key)
      if txi <= max_txi, do: Map.put(acc, contract_pk, txi), else: acc
    end)
  end

  @spec update_aex9_state(State.t(), pubkey(), block_index(), txi()) :: State.t()
  def update_aex9_state(state, contract_pk, block_index, txi) do
    if AexnContracts.is_aex9?(contract_pk) do
      with false <- State.exists?(state, Model.AexnContract, {:aex9, contract_pk}),
           {:ok, extensions} <- AexnContracts.call_extensions(:aex9, contract_pk),
           {:ok, aex9_meta_info} <- AexnContracts.call_meta_info(:aex9, contract_pk) do
        state
        |> State.enqueue(:update_aex9_state, [contract_pk], [block_index, txi])
        |> aexn_creation_write(:aex9, aex9_meta_info, contract_pk, txi, extensions)
      else
        true ->
          State.enqueue(state, :update_aex9_state, [contract_pk], [block_index, txi])

        :error ->
          state
      end
    else
      state
    end
  end

  @spec write_aex141_records(State.t(), hash(), pubkey(), txi(), log_idx(), list(binary())) ::
          State.t()
  def write_aex141_records(state, hash, contract_pk, txi, i, args) do
    cond do
      hash == AeMdw.Node.aexn_mint_event_hash() ->
        write_aex141_ownership(state, contract_pk, args)

      hash == AeMdw.Node.aexn_transfer_event_hash() ->
        state
        |> write_aex141_ownership(contract_pk, args)
        |> write_aexn_transfer(:aex141, contract_pk, txi, i, args)

      true ->
        state
    end
  end

  @spec write_aex141_ownership(State.t(), pubkey(), list(binary())) :: State.t()
  def write_aex141_ownership(
        state,
        contract_pk,
        [<<_to_pk::256>>, <<_token_id::256>>] = args
      ) do
    do_write_aex141_ownership(state, contract_pk, args)
  end

  def write_aex141_ownership(
        state,
        contract_pk,
        [<<_from::256>>, <<_pk2::256>> = to_pk, <<_id::256>> = token_id]
      ) do
    do_write_aex141_ownership(state, contract_pk, [to_pk, token_id])
  end

  def write_aex141_ownership(state, _contract_pk, _args), do: state

  defp do_write_aex141_ownership(state, contract_pk, [to_pk, <<token_id::256>>]) do
    m_ownership = Model.nft_ownership(index: {to_pk, contract_pk, token_id})
    m_owner_token = Model.nft_owner_token(index: {contract_pk, to_pk, token_id})
    m_token_owner = Model.nft_token_owner(index: {contract_pk, token_id}, owner: to_pk)

    prev_owner_pk = previous_owner(state, contract_pk, token_id)

    state
    |> delete_previous_ownership(contract_pk, token_id, prev_owner_pk, to_pk)
    |> SyncStats.update_nft_stats(contract_pk, prev_owner_pk, to_pk)
    |> State.put(Model.NftOwnership, m_ownership)
    |> State.put(Model.NftOwnerToken, m_owner_token)
    |> State.put(Model.NftTokenOwner, m_token_owner)
  end

  #
  # Private functions
  #
  defp previous_owner(state, contract_pk, token_id) do
    case State.get(state, Model.NftTokenOwner, {contract_pk, token_id}) do
      {:ok, Model.nft_token_owner(owner: prev_owner_pk)} ->
        prev_owner_pk

      :not_found ->
        nil
    end
  end

  defp delete_previous_ownership(state, contract_pk, token_id, prev_owner_pk, to_pk) do
    if prev_owner_pk != to_pk and prev_owner_pk != nil do
      state
      |> State.delete(Model.NftOwnership, {prev_owner_pk, contract_pk, token_id})
      |> State.delete(Model.NftOwnerToken, {contract_pk, prev_owner_pk, token_id})
    else
      state
    end
  end

  defp aex9_search_transfers(state, table, init_key, key_tester) do
    state
    |> Collection.stream(table, init_key)
    |> Stream.take_while(key_tester)
  end

  defp maybe_index_remote_log(
         state,
         contract_pk,
         _block_index,
         _txi,
         {{contract_pk, _event, _data}, _i}
       ),
       do: state

  defp maybe_index_remote_log(
         state,
         contract_pk,
         block_index,
         txi,
         {{log_pk, [evt_hash | args], data}, i}
       ) do
    remote_contract_txi = Origin.tx_index!(state, {:contract, log_pk})

    # on caller log: ext_contract = called contract_pk
    # on called log: ext_contract = {:parent_contract_pk, caller contract_pk}
    m_log_remote =
      Model.contract_log(
        index: {remote_contract_txi, txi, evt_hash, i},
        ext_contract: {:parent_contract_pk, contract_pk},
        args: args,
        data: data
      )

    state
    |> State.put(Model.ContractLog, m_log_remote)
    |> update_aex9_state(log_pk, block_index, txi)
  end

  defp write_aexn_transfer(
         state,
         aexn_type,
         contract_pk,
         txi,
         i,
         [
           <<_pk1::256>> = from_pk,
           <<_pk2::256>> = to_pk,
           <<value::256>>
         ] = transfer
       ) do
    m_transfer =
      Model.aexn_transfer(
        index: {aexn_type, from_pk, txi, to_pk, value, i},
        contract_pk: contract_pk
      )

    m_rev_transfer = Model.rev_aexn_transfer(index: {aexn_type, to_pk, txi, from_pk, value, i})
    m_pair_transfer = Model.aexn_pair_transfer(index: {aexn_type, from_pk, to_pk, txi, value, i})

    state
    |> State.put(Model.AexnTransfer, m_transfer)
    |> State.put(Model.RevAexnTransfer, m_rev_transfer)
    |> State.put(Model.AexnPairTransfer, m_pair_transfer)
    |> maybe_index_contract_transfer(aexn_type, contract_pk, txi, i, transfer)
  end

  defp write_aexn_transfer(state, _type, _pk, _txi, _i, _args), do: state

  defp maybe_index_contract_transfer(state, :aex9, _pk, _txi, _i, _transfer), do: state

  defp maybe_index_contract_transfer(state, :aex141, contract_pk, txi, i, [
         from_pk,
         to_pk,
         <<token_id::256>>
       ]) do
    create_txi = Origin.tx_index!(state, {:contract, contract_pk})

    m_ct_from =
      Model.aexn_contract_from_transfer(index: {create_txi, from_pk, txi, to_pk, token_id, i})

    m_ct_to =
      Model.aexn_contract_to_transfer(index: {create_txi, to_pk, txi, from_pk, token_id, i})

    state
    |> State.put(Model.AexnContractFromTransfer, m_ct_from)
    |> State.put(Model.AexnContractToTransfer, m_ct_to)
  end

  defp fetch_aex9_balance_or_new(state, contract_pk, account_pk) do
    case State.get(state, Model.Aex9Balance, {contract_pk, account_pk}) do
      {:ok, m_balance} -> m_balance
      :not_found -> Model.aex9_balance(index: {contract_pk, account_pk}, amount: 0)
    end
  end
end

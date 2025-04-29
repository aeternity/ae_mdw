defmodule AeMdw.Db.Contract do
  @moduledoc """
  Data access to read and write Contract related models.
  """

  alias AeMdw.Db.Sync.IdCounter
  alias AeMdw.Aex9
  alias AeMdw.AexnContracts
  alias AeMdw.Collection
  alias AeMdw.Contract
  alias AeMdw.Fields
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.ActiveEntities
  alias AeMdw.Db.Sync.Stats, as: SyncStats
  alias AeMdw.Db.Util
  alias AeMdw.Dex
  alias AeMdw.Log
  alias AeMdw.Node
  alias AeMdw.Node.Db

  require Ex2ms
  require Log
  require Model
  require Record

  import AeMdwWeb.Helpers.AexnHelper, only: [sort_field_truncate: 1]

  @typep pubkey :: Db.pubkey()
  @typep state :: State.t()
  @typep txi :: AeMdw.Txs.txi()
  @typep txi_idx :: AeMdw.Txs.txi_idx()

  @typep call_tx_args :: Contract.call_tx_args()
  @typep call_tx_res :: Contract.call_tx_res()

  @type log_data() :: binary()
  @type rev_aex9_contract_key :: {pos_integer(), String.t(), String.t(), pos_integer()}
  @type account_balance :: {pubkey(), integer()}

  @dex_factory_pubkeys Application.compile_env(:ae_mdw, :dex_factories)
  @ae_token_contract_pks Application.compile_env(:ae_mdw, :ae_token)

  @spec dex_factory_pubkey :: pubkey()
  def dex_factory_pubkey, do: Map.get(@dex_factory_pubkeys, :aec_governance.get_network_id())

  @spec get_aexn_type(State.t(), pubkey()) :: Model.aexn_type() | nil
  def get_aexn_type(state, contract_pk) do
    cond do
      State.exists?(state, Model.AexnContract, {:aex9, contract_pk}) -> :aex9
      State.exists?(state, Model.AexnContract, {:aex141, contract_pk}) -> :aex141
      true -> nil
    end
  end

  @spec aexn_creation_write(
          state(),
          Model.aexn_type(),
          Model.aexn_meta_info(),
          pubkey(),
          txi_idx(),
          Model.aexn_extensions()
        ) :: state()
  def aexn_creation_write(state, aexn_type, aexn_meta_info, contract_pk, txi_idx, extensions) do
    m_contract_pk =
      Model.aexn_contract(
        index: {aexn_type, contract_pk},
        txi_idx: txi_idx,
        meta_info: aexn_meta_info,
        extensions: extensions
      )

    state2 = State.put(state, Model.AexnContract, m_contract_pk)

    if AexnContracts.valid_meta_info?(aexn_meta_info) do
      name = elem(aexn_meta_info, 0)
      symbol = elem(aexn_meta_info, 1)

      m_contract_creation =
        Model.aexn_contract_creation(index: {aexn_type, txi_idx}, contract_pk: contract_pk)

      truncated_name = sort_field_truncate(name)

      m_contract_name = Model.aexn_contract_name(index: {aexn_type, truncated_name, contract_pk})

      m_downcased_contract_name =
        Model.aexn_contract_downcased_name(
          index: {aexn_type, String.downcase(truncated_name), contract_pk},
          original_name: name
        )

      truncated_symbol = sort_field_truncate(symbol)

      m_contract_sym =
        Model.aexn_contract_symbol(index: {aexn_type, truncated_symbol, contract_pk})

      m_downcased_contract_sym =
        Model.aexn_contract_downcased_symbol(
          index: {aexn_type, String.downcase(truncated_symbol), contract_pk},
          original_symbol: symbol
        )

      state2
      |> State.put(Model.AexnContractName, m_contract_name)
      |> State.put(Model.AexnContractDowncasedName, m_downcased_contract_name)
      |> State.put(Model.AexnContractSymbol, m_contract_sym)
      |> State.put(Model.AexnContractDowncasedSymbol, m_downcased_contract_sym)
      |> State.put(Model.AexnContractCreation, m_contract_creation)
    else
      state2
    end
  end

  @spec aex9_write_presence(state(), pubkey(), txi(), pubkey()) :: state()
  def aex9_write_presence(state, contract_pk, txi, account_pk) do
    m_acc_presence = Model.aex9_account_presence(index: {account_pk, contract_pk}, txi: txi)

    state
    |> State.put(Model.Aex9AccountPresence, m_acc_presence)
  end

  @spec aex9_burn_update_holders(state(), pubkey(), integer(), txi(), pubkey()) :: state()
  def aex9_burn_update_holders(state, contract_pk, balance, txi, from_pk) do
    case balance do
      0 ->
        state
        |> SyncStats.decrement_aex9_holders(contract_pk, txi)
        |> IdCounter.decr_account_aex9_count(from_pk)

      balance when balance < 0 ->
        state
        |> State.put(
          Model.AexnInvalidContract,
          Model.aexn_invalid_contract(
            index: {:aex9, contract_pk},
            reason: Aex9.invalid_holder_balance_reason(),
            description: "Invalid balance of #{balance} at tx #{txi}"
          )
        )
        |> IdCounter.decr_account_aex9_count(from_pk)

      _larger_than_zero ->
        state
    end
  end

  defp aex9_mint_update_holders(state, contract_pk, account_pk) do
    if State.exists?(state, Model.Aex9AccountPresence, {account_pk, contract_pk}) do
      state
    else
      SyncStats.increment_aex9_holders(state, contract_pk)
    end
  end

  defp aex9_transfer_update_holders(
         state,
         contract_pk,
         from_balance,
         to_prev_amount,
         txi,
         from_account
       ) do
    cond do
      from_balance <= 0 and to_prev_amount > 0 ->
        state
        |> SyncStats.decrement_aex9_holders(contract_pk, txi)
        |> IdCounter.decr_account_aex9_count(from_account)

      from_balance <= 0 ->
        # decrement and increment
        IdCounter.decr_account_aex9_count(state, from_account)

      to_prev_amount == 0 ->
        SyncStats.increment_aex9_holders(state, contract_pk)

      true ->
        state
    end
  end

  @spec aex9_delete_presence(state(), pubkey(), pubkey()) :: state()
  def aex9_delete_presence(state, account_pk, contract_pk) do
    if State.exists?(state, Model.Aex9AccountPresence, {account_pk, contract_pk}) do
      state
      |> State.delete(Model.Aex9AccountPresence, {account_pk, contract_pk})
      |> IdCounter.decr_account_aex9_count(account_pk)
    else
      state
    end
  end

  @spec aex9_init_event_balances(state(), pubkey(), [account_balance()], txi()) :: state()
  def aex9_init_event_balances(state, contract_pk, balances, txi) do
    initial_sum =
      balances |> Enum.map(fn {_account_pk, initial_amount} -> initial_amount end) |> Enum.sum()

    state =
      State.put(
        state,
        Model.Aex9InitialSupply,
        Model.aex9_initial_supply(index: contract_pk, amount: initial_sum)
      )

    Enum.reduce(balances, state, fn {account_pk, initial_amount}, state ->
      m_balance =
        case State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk}) do
          :not_found ->
            Model.aex9_event_balance(
              index: {contract_pk, account_pk},
              txi: txi,
              log_idx: -1,
              amount: initial_amount
            )

          {:ok, Model.aex9_event_balance(amount: amount) = m_balance} ->
            Model.aex9_event_balance(m_balance, amount: initial_amount + amount)
        end

      amount = Model.aex9_event_balance(m_balance, :amount)

      m_bal_account =
        Model.aex9_balance_account(index: {contract_pk, amount, account_pk}, txi: txi)

      state =
        if amount > 0 do
          SyncStats.increment_aex9_holders(state, contract_pk)
        else
          state
        end

      state
      |> State.put(Model.Aex9EventBalance, m_balance)
      |> State.put(Model.Aex9BalanceAccount, m_bal_account)
      |> aex9_write_presence(contract_pk, txi, account_pk)
      |> aex9_update_contract_balance(contract_pk, amount)
    end)
  end

  @spec call_write(state(), txi(), txi(), Contract.fun_arg_res_or_error()) :: state()
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

  def call_write(state, create_txi, txi, :error),
    do: call_write(state, create_txi, txi, "<unknown>", nil, :invalid, "error")

  @spec call_write(state(), txi(), txi(), String.t(), call_tx_args(), call_tx_res(), any()) ::
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

    field_pos = Fields.mdw_field_pos("entrypoint")
    m_entrypoint_field = Model.field(index: {:contract_call_tx, field_pos, fname, txi})

    state
    |> State.put(Model.ContractCall, m_call)
    |> State.put(Model.Field, m_entrypoint_field)
    |> ActiveEntities.track(result, create_txi, txi, fname, args)
  end

  @spec logs_write(state(), txi(), txi(), Contract.call(), boolean()) :: state()
  def logs_write(state, create_txi, txi, call_rec, is_contract_creation?) do
    contract_pk = :aect_call.contract_pubkey(call_rec)

    call_rec
    |> :aect_call.log()
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.reduce(state, fn {{addr, [evt_hash | args], data}, log_idx} = log, state ->
      m_log =
        Model.contract_log(
          index: {create_txi, txi, log_idx},
          ext_contract: (addr != contract_pk && addr) || nil,
          args: args,
          data: data,
          hash: evt_hash
        )

      m_data_log = Model.data_contract_log(index: {data, txi, create_txi, log_idx})
      m_evt_log = Model.evt_contract_log(index: {evt_hash, txi, create_txi, log_idx})
      m_ctevt_log = Model.ctevt_contract_log(index: {evt_hash, create_txi, txi, log_idx})
      m_idx_log = Model.idx_contract_log(index: {txi, log_idx, create_txi})

      state2 =
        state
        |> State.put(Model.ContractLog, m_log)
        |> State.put(Model.DataContractLog, m_data_log)
        |> State.put(Model.EvtContractLog, m_evt_log)
        |> State.put(Model.CtEvtContractLog, m_ctevt_log)
        |> State.put(Model.IdxContractLog, m_idx_log)
        |> maybe_index_remote_log(contract_pk, txi, log)

      aex9_contract_pk = which_aex9_contract_pubkey(contract_pk, addr)

      event_type =
        Map.get(Node.aexn_event_hash_types(), evt_hash) ||
          Map.get(Node.dex_event_hash_types(), evt_hash)

      event_type = maybe_fix_event_type_for_wae(event_type, contract_pk)

      cond do
        event_type == :pair_created ->
          write_pair_created(state, addr, args)

        event_type == :swap_tokens ->
          write_swap_tokens(state, create_txi, txi, log_idx, args, data)

        aex9_contract_pk != nil ->
          # for parent contracts on contract creation or for child contracts on contract calls,
          # the balance is updated via dry-run to get minted tokens without events
          update_balance? = not is_contract_creation?

          state2
          |> SyncStats.increment_aex9_logs(aex9_contract_pk)
          |> write_aex9_records(event_type, {addr, update_balance?}, txi, log_idx, args)

        State.exists?(state2, Model.AexnContract, {:aex141, addr}) ->
          write_aex141_records(state2, event_type, addr, txi, log_idx, args)

        true ->
          state2
      end
    end)
  end

  @spec which_aex9_contract_pubkey(pubkey(), pubkey()) :: pubkey() | nil
  def which_aex9_contract_pubkey(contract_pk, addr) do
    if AexnContracts.aex9?(contract_pk) do
      contract_pk
    else
      # remotely called contract is aex9?
      if addr != contract_pk and AexnContracts.aex9?(addr), do: addr
    end
  end

  @spec call_fun_arg_res(State.t(), pubkey(), txi()) :: Contract.fun_arg_res()
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
      {:aex9, sender_pk, -1, -1, nil, -1},
      fn key ->
        elem(key, 0) == :aex9 and elem(key, 1) == sender_pk
      end
    )
  end

  def aex9_search_transfers(state, {:to, recipient_pk}) do
    aex9_search_transfers(
      state,
      Model.RevAexnTransfer,
      {:aex9, recipient_pk, -1, -1, nil, -1},
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

  @spec aex9_balance_txi(State.t(), pubkey(), txi()) :: txi()
  def aex9_balance_txi(state, contract_pk, upper_txi) do
    create_txi = Origin.tx_index!(state, {:contract, contract_pk})

    case State.prev(state, Model.ContractCall, {create_txi, upper_txi}) do
      {:ok, {^create_txi, call_txi}} -> call_txi
      _none_or_other -> create_txi
    end
  end

  @spec write_aex141_ownership(State.t(), pubkey(), list(binary())) :: State.t()
  def write_aex141_ownership(
        state,
        contract_pk,
        [<<_pk::256>> = to_pk, <<token_id::256>>]
      ) do
    do_write_aex141_ownership(state, contract_pk, to_pk, token_id)
  end

  def write_aex141_ownership(
        state,
        contract_pk,
        [<<_pk::256>> = to_pk, <<template_id::256>>, <<token_id::256>>, _edition]
      ) do
    do_write_aex141_ownership(state, contract_pk, to_pk, token_id, template_id)
  end

  def write_aex141_ownership(state, _contract_pk, _args), do: state

  #
  # Private functions
  #
  defp write_pair_created(state, contract_pk, [token1, token2, pair_pk]) do
    if contract_pk == dex_factory_pubkey() do
      Model.aexn_contract(meta_info: {_name, token1_symbol, _dec}) =
        State.fetch!(state, Model.AexnContract, {:aex9, token1})

      Model.aexn_contract(meta_info: {_name, token2_symbol, _dec}) =
        State.fetch!(state, Model.AexnContract, {:aex9, token2})

      {:ok, pair_create_txi_idx} = Origin.creation_txi_idx(state, pair_pk)

      state
      |> State.put(
        Model.DexPair,
        Model.dex_pair(index: pair_pk, token1_pk: token1, token2_pk: token2)
      )
      |> State.put(
        Model.DexTokenSymbol,
        Model.dex_token_symbol(index: token1_symbol, pair_create_txi_idx: pair_create_txi_idx)
      )
      |> State.put(
        Model.DexTokenSymbol,
        Model.dex_token_symbol(index: token2_symbol, pair_create_txi_idx: pair_create_txi_idx)
      )
    else
      state
    end
  end

  defp write_pair_created(state, _contract_pk, _args), do: state

  defp write_swap_tokens(state, create_txi, txi, idx, [from, to], amounts) do
    if String.printable?(amounts) do
      create_txi = Dex.get_create_txi(state, create_txi, txi, idx)
      pair_pk = Dex.get_pair_pk(state, create_txi, txi, idx)

      case State.get(state, Model.DexPair, pair_pk) do
        {:ok, Model.dex_pair(token1_pk: token1_pk, token2_pk: token2_pk)} ->
          amounts = amounts |> String.split("|") |> Enum.map(&String.to_integer/1)
          {:ok, token1_create_txi_idx} = Origin.creation_txi_idx(state, token1_pk)
          {:ok, token2_create_txi_idx} = Origin.creation_txi_idx(state, token2_pk)

          state
          |> State.put(
            Model.DexAccountSwapTokens,
            Model.dex_account_swap_tokens(
              index: {from, create_txi, txi, idx},
              to: to,
              amounts: amounts
            )
          )
          |> IdCounter.incr_account_activities_count(from)
          |> IdCounter.incr_account_activities_count(to)
          |> State.put(
            Model.DexContractSwapTokens,
            Model.dex_contract_swap_tokens(index: {create_txi, from, txi, idx})
          )
          |> State.put(
            Model.DexSwapTokens,
            Model.dex_swap_tokens(index: {txi, idx, create_txi})
          )
          |> State.put(
            Model.DexContractTokenSwap,
            Model.dex_contract_token_swap(
              index: {token1_create_txi_idx, txi, idx},
              contract_call_create_txi: create_txi
            )
          )
          |> State.put(
            Model.DexContractTokenSwap,
            Model.dex_contract_token_swap(
              index: {token2_create_txi_idx, txi, idx},
              contract_call_create_txi: create_txi
            )
          )

        :not_found ->
          Log.warn(
            "[write_swap_tokens] pair not found: #{inspect(pair_pk)} (#{inspect({txi, idx})})"
          )

          state
      end
    else
      Log.warn("[write_swap_tokens] amounts not printable: #{create_txi}")

      state
    end
  end

  defp write_swap_tokens(state, _create_txi, _txi, _idx, _args, _amounts), do: state

  defp aex9_update_balance_account(
         state,
         contract_pk,
         old_amount,
         new_amount,
         pubkey,
         txi,
         log_idx
       ) do
    m_from_account =
      Model.aex9_balance_account(
        index: {contract_pk, new_amount, pubkey},
        txi: txi,
        log_idx: log_idx
      )

    state =
      if State.exists?(state, Model.Aex9BalanceAccount, {contract_pk, old_amount, pubkey}) do
        State.delete(state, Model.Aex9BalanceAccount, {contract_pk, old_amount, pubkey})
      else
        state
      end

    State.put(state, Model.Aex9BalanceAccount, m_from_account)
  end

  defp transfer_aex141_ownership(
         state,
         contract_pk,
         [<<_from::256>>, <<_pk::256>> = to_pk, <<token_id::256>>]
       ) do
    do_write_aex141_ownership(state, contract_pk, to_pk, token_id)
  end

  defp transfer_aex141_ownership(state, _contract_pk, _args), do: state

  defp write_aex141_edition_limit(state, event_type, contract_pk, txi, log_idx, args) do
    with {template_id, limit} <- get_edition_limit_from_args(event_type, args),
         {:ok, m_template} <- State.get(state, Model.NftTemplate, {contract_pk, template_id}) do
      State.put(
        state,
        Model.NftTemplate,
        Model.nft_template(m_template, limit: {limit, txi, log_idx})
      )
    else
      nil -> state
      :not_found -> state
    end
  end

  defp write_aex141_limit(state, event_type, contract_pk, args, txi, log_idx) do
    m_new_nft_limit = Model.nft_contract_limits(index: contract_pk, txi: txi, log_idx: log_idx)
    limit = get_nft_limit_from_args(event_type, args)

    upsert_aex141_limit(state, event_type, m_new_nft_limit, limit)
  end

  defp upsert_aex141_limit(state, _event_type, _m_nft_limit, nil), do: state

  defp upsert_aex141_limit(
         state,
         event_type,
         Model.nft_contract_limits(index: contract_pk) = m_nft_limit,
         limit
       )
       when event_type in [:token_limit, :token_limit_decrease] do
    State.update(
      state,
      Model.NftContractLimits,
      contract_pk,
      &Model.nft_contract_limits(&1, token_limit: limit),
      Model.nft_contract_limits(m_nft_limit, token_limit: limit)
    )
  end

  defp upsert_aex141_limit(
         state,
         _event_type,
         Model.nft_contract_limits(index: contract_pk) = m_nft_limit,
         limit
       ) do
    State.update(
      state,
      Model.NftContractLimits,
      contract_pk,
      &Model.nft_contract_limits(&1, template_limit: limit),
      Model.nft_contract_limits(m_nft_limit, template_limit: limit)
    )
  end

  defp get_nft_limit_from_args(event_type, [<<limit::256>>])
       when event_type in [:token_limit, :template_limit],
       do: limit

  defp get_nft_limit_from_args(event_type, [<<_::256>>, <<limit::256>>])
       when event_type in [:token_limit_decrease, :template_limit_decrease],
       do: limit

  defp get_nft_limit_from_args(_event_type, _args), do: nil

  defp get_edition_limit_from_args(:edition_limit, [<<template_id::256>>, <<limit::256>>]),
    do: {template_id, limit}

  defp get_edition_limit_from_args(:edition_limit_decrease, [
         <<template_id::256>>,
         <<_old_limit::256>>,
         <<limit::256>>
       ]),
       do: {template_id, limit}

  defp get_edition_limit_from_args(_event_type, _args), do: nil

  defp delete_aex141_template(
         state,
         contract_pk,
         [<<template_id::256>>]
       ) do
    if State.exists?(state, Model.NftTemplate, {contract_pk, template_id}) do
      State.delete(state, Model.NftTemplate, {contract_pk, template_id})
    else
      state
    end
  end

  defp delete_aex141_template(state, _pk, _args), do: state

  defp delete_aex141_ownership(state, contract_pk, token_id) do
    prev_owner_pk = previous_owner(state, contract_pk, token_id)

    state
    |> delete_previous_ownership(contract_pk, token_id, prev_owner_pk)
    |> SyncStats.update_nft_stats(contract_pk, prev_owner_pk, nil)
  end

  defp do_write_aex141_ownership(state, contract_pk, to_pk, token_id, template_id \\ nil) do
    m_ownership =
      Model.nft_ownership(index: {to_pk, contract_pk, token_id}, template_id: template_id)

    m_owner_token = Model.nft_owner_token(index: {contract_pk, to_pk, token_id})
    m_token_owner = Model.nft_token_owner(index: {contract_pk, token_id}, owner: to_pk)

    prev_owner_pk = previous_owner(state, contract_pk, token_id)

    state
    |> delete_previous_ownership(contract_pk, token_id, prev_owner_pk)
    |> SyncStats.update_nft_stats(contract_pk, prev_owner_pk, to_pk)
    |> State.put(Model.NftOwnership, m_ownership)
    |> State.put(Model.NftOwnerToken, m_owner_token)
    |> State.put(Model.NftTokenOwner, m_token_owner)
    |> IdCounter.incr_account_aex141_with_activities_count(to_pk)
  end

  defp write_aex9_records(state, event_type, {contract_pk, update_balance?}, txi, log_idx, args) do
    case event_type do
      :burn when update_balance? ->
        burn_aex9_balance(state, contract_pk, txi, log_idx, args)

      :mint when update_balance? ->
        mint_aex9_balance(state, contract_pk, txi, log_idx, args)

      :swap when update_balance? ->
        burn_aex9_balance(state, contract_pk, txi, log_idx, args)

      :transfer ->
        write_aexn_transfer(state, :aex9, {contract_pk, update_balance?}, txi, log_idx, args)

      _other ->
        state
    end
  end

  defp write_aex141_records(state, :burn, contract_pk, _txi, _log_idx, [
         _owner_pk,
         <<token_id::256>>
       ]) do
    state = delete_aex141_ownership(state, contract_pk, token_id)

    case State.get(state, Model.NftTokenTemplate, {contract_pk, token_id}) do
      {:ok, Model.nft_token_template(template: template_id)} ->
        state
        |> SyncStats.decrement_nft_template_tokens(contract_pk, template_id)
        |> State.delete(Model.NftTokenTemplate, {contract_pk, token_id})
        |> State.delete(Model.NftTemplateToken, {contract_pk, template_id, token_id})

      :not_found ->
        state
    end
  end

  defp write_aex141_records(state, :mint, contract_pk, _txi, _log_idx, args) do
    write_aex141_ownership(state, contract_pk, args)
  end

  defp write_aex141_records(
         state,
         :template_mint,
         contract_pk,
         txi,
         log_idx,
         [<<_pk::256>>, <<template_id::256>>, <<token_id::256>>, edition] = args
       ) do
    state
    |> write_aex141_ownership(contract_pk, args)
    |> State.put(
      Model.NftTokenTemplate,
      Model.nft_token_template(index: {contract_pk, token_id}, template: template_id)
    )
    |> State.put(
      Model.NftTemplateToken,
      Model.nft_template_token(
        index: {contract_pk, template_id, token_id},
        txi: txi,
        log_idx: log_idx,
        edition: edition
      )
    )
    |> SyncStats.increment_nft_template_tokens(contract_pk, template_id)
  end

  defp write_aex141_records(state, event_type, contract_pk, txi, log_idx, args)
       when event_type in [:edition_limit, :edition_limit_decrease] do
    write_aex141_edition_limit(state, event_type, contract_pk, txi, log_idx, args)
  end

  defp write_aex141_records(state, event_type, contract_pk, txi, log_idx, args)
       when event_type in [
              :token_limit,
              :token_limit_decrease,
              :template_limit,
              :template_limit_decrease
            ] do
    write_aex141_limit(state, event_type, contract_pk, args, txi, log_idx)
  end

  defp write_aex141_records(state, :template_creation, contract_pk, txi, log_idx, [
         <<template_id::256>>
       ]) do
    if State.exists?(state, Model.NftTemplate, {contract_pk, template_id}) do
      state
    else
      m_template =
        Model.nft_template(index: {contract_pk, template_id}, txi: txi, log_idx: log_idx)

      State.put(state, Model.NftTemplate, m_template)
    end
  end

  defp write_aex141_records(state, :template_creation, _contract_pk, _txi, _log_idx, _other_arg),
    do: state

  defp write_aex141_records(state, :template_deletion, contract_pk, _txi, _log_idx, args) do
    delete_aex141_template(state, contract_pk, args)
  end

  defp write_aex141_records(state, :transfer, contract_pk, txi, log_idx, args) do
    state
    |> transfer_aex141_ownership(contract_pk, args)
    |> write_aexn_transfer(:aex141, {contract_pk, false}, txi, log_idx, args)
  end

  defp write_aex141_records(state, _any, _contract_pk, _txi, _log_idx, _args), do: state

  defp previous_owner(state, contract_pk, token_id) do
    case State.get(state, Model.NftTokenOwner, {contract_pk, token_id}) do
      {:ok, Model.nft_token_owner(owner: prev_owner_pk)} ->
        prev_owner_pk

      :not_found ->
        nil
    end
  end

  defp delete_previous_ownership(state, contract_pk, token_id, prev_owner_pk) do
    if prev_owner_pk != nil do
      state
      |> State.delete(Model.NftOwnership, {prev_owner_pk, contract_pk, token_id})
      |> State.delete(Model.NftOwnerToken, {contract_pk, prev_owner_pk, token_id})
      |> State.delete(Model.NftTokenOwner, {contract_pk, token_id})
      |> IdCounter.decr_account_aex141_with_activities_count(prev_owner_pk)
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
         _txi,
         {{contract_pk, _event, _data}, _i}
       ),
       do: state

  defp maybe_index_remote_log(
         state,
         contract_pk,
         txi,
         {{log_pk, [evt_hash | args], data}, idx}
       ) do
    remote_contract_txi = Origin.tx_index!(state, {:contract, log_pk})

    # on caller log: ext_contract = called contract_pk
    # on called log: ext_contract = {:parent_contract_pk, caller contract_pk}
    m_log_remote =
      Model.contract_log(
        index: {remote_contract_txi, txi, idx},
        ext_contract: {:parent_contract_pk, contract_pk},
        args: args,
        data: data,
        hash: evt_hash
      )

    m_evt_log = Model.evt_contract_log(index: {evt_hash, txi, remote_contract_txi, idx})
    m_ctevt_log = Model.ctevt_contract_log(index: {evt_hash, remote_contract_txi, txi, idx})

    state
    |> State.put(Model.ContractLog, m_log_remote)
    |> State.put(Model.EvtContractLog, m_evt_log)
    |> State.put(Model.CtEvtContractLog, m_ctevt_log)
  end

  defp write_aexn_transfer(
         state,
         aexn_type,
         {contract_pk, update_balance?},
         txi,
         log_idx,
         [
           <<_pk1::256>> = from_pk,
           <<_pk2::256>> = to_pk,
           <<value::256>>
         ] = transfer
       ) do
    m_transfer =
      Model.aexn_transfer(
        index: {aexn_type, from_pk, txi, log_idx, to_pk, value},
        contract_pk: contract_pk
      )

    m_rev_transfer =
      Model.rev_aexn_transfer(index: {aexn_type, to_pk, txi, log_idx, from_pk, value})

    m_pair_transfer =
      Model.aexn_pair_transfer(index: {aexn_type, from_pk, to_pk, txi, log_idx, value})

    state
    |> State.put(Model.AexnTransfer, m_transfer)
    |> State.put(Model.RevAexnTransfer, m_rev_transfer)
    |> State.put(Model.AexnPairTransfer, m_pair_transfer)
    |> SyncStats.increment_statistics(:aex9_transfers, Util.txi_to_time(state, txi), 1)
    |> index_contract_transfer(contract_pk, txi, log_idx, transfer)
    |> update_transfer_balance(aexn_type, {contract_pk, update_balance?}, txi, log_idx, transfer)
    |> then(fn st ->
      case aexn_type do
        :aex9 ->
          st
          |> IdCounter.incr_account_activities_count(from_pk)
          |> IdCounter.incr_account_aex9_with_activities_count(to_pk)

        :aex141 ->
          st
      end
    end)
  end

  defp write_aexn_transfer(state, _type, _pk, _txi, _log_idx, _args), do: state

  defp index_contract_transfer(state, contract_pk, txi, i, [
         from_pk,
         to_pk,
         <<value::256>>
       ]) do
    create_txi = Origin.tx_index!(state, {:contract, contract_pk})

    m_ct_from =
      Model.aexn_contract_from_transfer(index: {create_txi, from_pk, txi, i, to_pk, value})

    m_ct_to = Model.aexn_contract_to_transfer(index: {create_txi, to_pk, txi, i, from_pk, value})

    state
    |> State.put(Model.AexnContractFromTransfer, m_ct_from)
    |> State.put(Model.AexnContractToTransfer, m_ct_to)
  end

  defp burn_aex9_balance(state, contract_pk, txi, log_idx, [from_pk, <<burn_value::256>>]) do
    Model.aex9_event_balance(amount: from_amount) =
      m_from = get_aex9_event_balance(state, contract_pk, from_pk)

    new_amount = from_amount - burn_value

    m_from =
      Model.aex9_event_balance(m_from,
        txi: txi,
        log_idx: log_idx,
        amount: new_amount
      )

    m_transfer =
      Model.aexn_transfer(
        index: {:aex9, from_pk, txi, log_idx, nil, burn_value},
        contract_pk: contract_pk
      )

    IO.inspect(new_amount, label: "new_amount")

    state
    |> State.put(Model.Aex9EventBalance, m_from)
    |> State.put(Model.AexnTransfer, m_transfer)
    |> SyncStats.increment_statistics(:aex9_transfers, Util.txi_to_time(state, txi), 1)
    |> IdCounter.incr_account_activities_count(from_pk)
    |> aex9_update_balance_account(contract_pk, from_amount, new_amount, from_pk, txi, log_idx)
    |> aex9_burn_update_holders(contract_pk, new_amount, txi, from_pk)
    |> aex9_update_contract_balance(contract_pk, -burn_value)
    |> aex9_write_presence(contract_pk, txi, from_pk)
  end

  defp burn_aex9_balance(state, _pk, _txi, _idx, _args), do: state

  defp mint_aex9_balance(state, contract_pk, txi, log_idx, [to_pk, <<mint_value::256>>]) do
    Model.aex9_event_balance(amount: to_amount) =
      m_to = get_aex9_event_balance(state, contract_pk, to_pk)

    new_amount = to_amount + mint_value

    m_to =
      Model.aex9_event_balance(m_to,
        txi: txi,
        log_idx: log_idx,
        amount: new_amount
      )

    m_transfer =
      Model.aexn_transfer(
        index: {:aex9, contract_pk, txi, log_idx, to_pk, mint_value},
        contract_pk: contract_pk
      )

    m_rev_transfer =
      Model.rev_aexn_transfer(index: {:aex9, to_pk, txi, log_idx, contract_pk, mint_value})

    state
    |> State.put(Model.Aex9EventBalance, m_to)
    |> State.put(Model.AexnTransfer, m_transfer)
    |> State.put(Model.RevAexnTransfer, m_rev_transfer)
    |> IdCounter.incr_account_aex9_with_activities_count(to_pk)
    |> SyncStats.increment_statistics(:aex9_transfers, Util.txi_to_time(state, txi), 1)
    |> aex9_update_balance_account(contract_pk, to_amount, new_amount, to_pk, txi, log_idx)
    |> aex9_mint_update_holders(contract_pk, to_pk)
    |> aex9_update_contract_balance(contract_pk, mint_value)
    |> aex9_write_presence(contract_pk, txi, to_pk)
  end

  defp mint_aex9_balance(state, _pk, _txi, _idx, _args), do: state

  defp update_transfer_balance(state, :aex141, _pk, _txi, _i, _transfer), do: state

  defp update_transfer_balance(state, :aex9, _pk, _txi, _i, [same_pk, same_pk, _value]), do: state

  defp update_transfer_balance(state, :aex9, {contract_pk, true}, txi, log_idx, [
         from_pk,
         to_pk,
         <<transfered_value::256>>
       ]) do
    Model.aex9_event_balance(amount: from_amount) =
      m_from = get_aex9_event_balance(state, contract_pk, from_pk)

    Model.aex9_event_balance(amount: to_amount) =
      m_to = get_aex9_event_balance(state, contract_pk, to_pk)

    new_to_amount = to_amount + transfered_value

    m_to =
      Model.aex9_event_balance(m_to,
        txi: txi,
        log_idx: log_idx,
        amount: new_to_amount
      )

    new_from_amount = from_amount - transfered_value

    m_from =
      Model.aex9_event_balance(m_from,
        txi: txi,
        log_idx: log_idx,
        amount: new_from_amount
      )

    IO.inspect(new_from_amount, label: "new_from_amount")

    state
    |> aex9_transfer_update_holders(contract_pk, new_from_amount, to_amount, txi, from_pk)
    |> State.put(Model.Aex9EventBalance, m_from)
    |> State.put(Model.Aex9EventBalance, m_to)
    |> aex9_update_balance_account(
      contract_pk,
      from_amount,
      new_from_amount,
      from_pk,
      txi,
      log_idx
    )
    |> aex9_update_balance_account(contract_pk, to_amount, new_to_amount, to_pk, txi, log_idx)
    |> aex9_write_presence(contract_pk, txi, to_pk)
  end

  defp update_transfer_balance(state, _type, _pk, _txi, _idx, _args), do: state

  defp aex9_update_contract_balance(state, contract_pk, delta_amount) do
    State.update(
      state,
      Model.Aex9ContractBalance,
      contract_pk,
      fn Model.aex9_contract_balance(amount: amount) = m_bal ->
        Model.aex9_contract_balance(m_bal, amount: amount + delta_amount)
      end,
      Model.aex9_contract_balance(index: contract_pk, amount: 0)
    )
  end

  defp get_aex9_event_balance(state, contract_pk, account_pk) do
    case State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk}) do
      {:ok, m_balance} -> m_balance
      :not_found -> Model.aex9_event_balance(index: {contract_pk, account_pk}, amount: 0)
    end
  end

  defp maybe_fix_event_type_for_wae(:deposit, contract_pk) do
    ae_token = Map.get(@ae_token_contract_pks, :aec_governance.get_network_id())

    if ae_token == contract_pk, do: :mint, else: nil
  end

  defp maybe_fix_event_type_for_wae(:withdrawal, contract_pk) do
    ae_token = Map.get(@ae_token_contract_pks, :aec_governance.get_network_id())

    if ae_token == contract_pk, do: :burn, else: nil
  end

  defp maybe_fix_event_type_for_wae(event_name, _contract_pk), do: event_name
end

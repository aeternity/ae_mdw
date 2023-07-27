defmodule AeMdw.Aex141 do
  @moduledoc """
  Returns NFT info interacting with AEX-141 contracts or from transfer history.
  """

  alias AeMdw.AexnContracts
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Stats
  alias AeMdw.Txs
  alias AeMdw.Util

  import AeMdw.Util.Encoding

  require Model

  @typep pagination :: Collection.direction_limit()
  @typep cursor :: binary() | nil
  @typep page_cursor :: Collection.pagination_cursor()
  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @typep limit :: integer() | nil
  @type limits :: %{
          token_limit: limit(),
          template_limit: limit(),
          limit_txi: Txs.txi() | nil,
          limit_log_idx: non_neg_integer() | nil
        }

  @type token_id :: integer()
  @type template_id :: integer()
  @type nft :: %{
          contract_id: String.t(),
          owner_id: String.t(),
          token_id: token_id()
        }
  @type template_nft :: %{
          token_id: token_id(),
          owner_id: String.t(),
          tx_hash: Txs.tx_hash(),
          log_idx: AeMdw.Contracts.log_idx()
        }

  @type metadata :: %{url: String.t()} | %{id: String.t()} | %{map: map()}

  @ownership_table Model.NftOwnership
  @templates_table Model.NftTemplate
  @template_tokens_table Model.NftTemplateToken
  @owners_table Model.NftTokenOwner

  @spec fetch_nft_metadata(State.t(), pubkey(), token_id()) ::
          {:ok, metadata()} | {:error, Error.t()}
  def fetch_nft_metadata(state, contract_pk, token_id) do
    with {:ok, return} <- call_contract(state, contract_pk, "metadata", [token_id]) do
      Model.aexn_contract(meta_info: {_name, _symbol, _url, metadata_type}) =
        State.fetch!(state, Model.AexnContract, {:aex141, contract_pk})

      decode_metadata(metadata_type, return)
    end
  end

  @spec fetch_nft_owner(State.t(), pubkey(), token_id()) :: {:ok, pubkey()} | {:error, Error.t()}
  def fetch_nft_owner(state, contract_pk, token_id) do
    with {:ok, return} <- call_contract(state, contract_pk, "owner", [token_id]) do
      case return do
        {:address, account_pk} -> {:ok, account_pk}
        mismatch -> {:error, ErrInput.ContractReturn.exception(value: inspect(mismatch))}
      end
    end
  end

  @spec fetch_owned_nfts(State.t(), pubkey(), cursor(), pagination()) ::
          {:ok, {page_cursor(), [nft()], page_cursor()}} | {:error, Error.t()}
  def fetch_owned_nfts(state, account_pk, cursor, pagination) do
    with {:ok, cursor_key} <- deserialize_cursor(@ownership_table, cursor) do
      {prev_cursor_key, nfts, next_cursor_key} =
        state
        |> build_streamer(@ownership_table, cursor_key, account_pk)
        |> Collection.paginate(pagination)

      {:ok,
       {
         serialize_cursor(prev_cursor_key),
         render_owned_nfs(nfts),
         serialize_cursor(next_cursor_key)
       }}
    end
  end

  @spec fetch_templates(State.t(), pubkey(), cursor(), pagination()) ::
          {:ok, {page_cursor(), [nft()], page_cursor()}} | {:error, Error.t()}
  def fetch_templates(state, account_pk, cursor, pagination) do
    with {:ok, cursor_key} <- deserialize_cursor(@templates_table, cursor) do
      {prev_cursor_key, keys, next_cursor_key} =
        state
        |> build_streamer(@templates_table, cursor_key, account_pk)
        |> Collection.paginate(pagination)

      {:ok,
       {
         serialize_cursor(prev_cursor_key),
         render_templates(state, keys),
         serialize_cursor(next_cursor_key)
       }}
    end
  end

  @spec fetch_template_tokens(State.t(), pubkey(), template_id(), cursor(), pagination()) ::
          {:ok, {page_cursor(), [template_nft()], page_cursor()}} | {:error, Error.t()}
  def fetch_template_tokens(state, contract_pk, template_id, cursor, pagination) do
    with {:ok, cursor_key} <- deserialize_cursor(@template_tokens_table, cursor) do
      {prev_cursor_key, keys, next_cursor_key} =
        state
        |> build_streamer(@template_tokens_table, cursor_key, {contract_pk, template_id})
        |> Collection.paginate(pagination)

      {:ok,
       {
         serialize_cursor(prev_cursor_key),
         render_template_tokens(state, keys),
         serialize_cursor(next_cursor_key)
       }}
    end
  end

  @spec fetch_collection_owners(State.t(), pubkey(), cursor(), pagination()) ::
          {:ok, {page_cursor(), [nft()], page_cursor()}} | {:error, Error.t()}
  def fetch_collection_owners(state, contract_pk, cursor, pagination) do
    with true <- State.exists?(state, Model.AexnContract, {:aex141, contract_pk}),
         {:ok, cursor_key} <- deserialize_cursor(@owners_table, cursor) do
      {prev_cursor_key, nft_tokens, next_cursor_key} =
        state
        |> build_streamer(@owners_table, cursor_key, contract_pk)
        |> Collection.paginate(pagination)

      {:ok,
       {
         serialize_cursor(prev_cursor_key),
         render_owners(state, nft_tokens),
         serialize_cursor(next_cursor_key)
       }}
    else
      false ->
        {:error, ErrInput.NotFound.exception(value: contract_pk)}

      cursor_error ->
        cursor_error
    end
  end

  @spec fetch_limits(State.t(), pubkey()) :: limits() | nil
  def fetch_limits(state, contract_pk) do
    Model.nft_contract_limits(
      token_limit: token_limit,
      template_limit: template_limit,
      txi: txi,
      log_idx: log_idx
    ) =
      case State.get(state, Model.NftContractLimits, contract_pk) do
        :not_found -> Model.nft_contract_limits()
        {:ok, m_limits} -> m_limits
      end

    if token_limit != nil or template_limit != nil do
      %{
        token_limit: token_limit,
        template_limit: template_limit,
        limit_txi: txi,
        limit_log_idx: log_idx
      }
    end
  end

  #
  # Private function
  #
  defp build_streamer(state, Model.NftTemplateToken, cursor_key, {contract_pk, template_id}) do
    key_boundary = {{contract_pk, template_id, -1}, {contract_pk, template_id, nil}}

    fn direction ->
      Collection.stream(state, Model.NftTemplateToken, direction, key_boundary, cursor_key)
    end
  end

  defp build_streamer(state, table, cursor_key, pubkey) do
    key_boundary =
      case table do
        Model.NftOwnership ->
          {
            {pubkey, <<>>, nil},
            {pubkey, Util.max_256bit_bin(), Util.max_int()}
          }

        Model.NftTemplate ->
          {{pubkey, Util.min_256bit_int()}, {pubkey, nil}}

        Model.NftTokenOwner ->
          {{pubkey, Util.min_256bit_int()}, {pubkey, nil}}
      end

    fn direction ->
      Collection.stream(state, table, direction, key_boundary, cursor_key)
    end
  end

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor({cursor, is_reversed?}),
    do: {cursor |> :erlang.term_to_binary() |> Base.encode64(), is_reversed?}

  defp deserialize_cursor(_table, nil), do: {:ok, nil}

  defp deserialize_cursor(Model.NftOwnership, cursor_bin64) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64),
         {<<_pk1::256>>, <<_pk2::256>>, token_id} = cursor when is_integer(token_id) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, cursor}
    else
      _invalid -> {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
    end
  end

  defp deserialize_cursor(Model.NftTemplate, cursor_bin64) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64),
         {<<_pk::256>>, template_id} = cursor when is_integer(template_id) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, cursor}
    else
      _invalid -> {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
    end
  end

  defp deserialize_cursor(Model.NftTemplateToken, cursor_bin64) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64),
         {<<_pk::256>>, template_id, token_id} = cursor
         when is_integer(template_id) and is_integer(token_id) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, cursor}
    else
      _invalid -> {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
    end
  end

  defp deserialize_cursor(Model.NftTokenOwner, cursor_bin64) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64),
         {<<_pk::256>>, token_id} = cursor when is_integer(token_id) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, cursor}
    else
      _invalid -> {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
    end
  end

  defp call_contract(state, contract_pk, entrypoint, args) do
    with true <- State.exists?(state, Model.AexnContract, {:aex141, contract_pk}),
         {:ok, {:variant, [0, 1], 1, {result}}} <-
           AexnContracts.call_contract(contract_pk, entrypoint, args) do
      {:ok, result}
    else
      false ->
        {:error, ErrInput.NotAex141.exception(value: encode_contract(contract_pk))}

      :error ->
        {:error, ErrInput.ContractDryRun.exception(value: encode_contract(contract_pk))}

      {:ok, unknown_return} ->
        {:error, ErrInput.ContractReturn.exception(value: inspect(unknown_return))}
    end
  end

  defp decode_metadata(meta_info_type, return) do
    case return do
      {:variant, [1, 1], 0, {metadata}} ->
        {:ok, %{meta_info_type => metadata}}

      {:variant, [1, 1], 1, {metadata}} ->
        {:ok, %{map: metadata}}

      mismatch ->
        {:error, ErrInput.ContractReturn.exception(value: inspect(mismatch))}
    end
  end

  defp render_owned_nfs(nfts) do
    Enum.map(nfts, fn {owner_pk, contract_pk, token_id} ->
      %{
        contract_id: encode_contract(contract_pk),
        owner_id: encode_account(owner_pk),
        token_id: token_id
      }
    end)
  end

  defp render_templates(state, keys) do
    Enum.map(keys, fn {contract_pk, template_id} ->
      Model.nft_template(txi: txi, log_idx: log_idx, limit: limit) =
        State.fetch!(state, @templates_table, {contract_pk, template_id})

      tx_hash = Txs.txi_to_hash(state, txi)

      %{
        contract_id: encode_contract(contract_pk),
        template_id: template_id,
        tx_hash: encode(:tx_hash, tx_hash),
        log_idx: log_idx,
        edition: render_template_edition(state, contract_pk, template_id, limit)
      }
    end)
  end

  defp render_template_tokens(state, keys) do
    Enum.map(keys, fn {contract_pk, template_id, token_id} ->
      Model.nft_template_token(txi: txi, log_idx: log_idx, edition: edition) =
        State.fetch!(state, @template_tokens_table, {contract_pk, template_id, token_id})

      Model.nft_token_owner(owner: owner_pk) =
        State.fetch!(state, @owners_table, {contract_pk, token_id})

      tx_hash = Txs.txi_to_hash(state, txi)

      %{
        edition: edition,
        token_id: token_id,
        owner_id: encode_account(owner_pk),
        tx_hash: encode(:tx_hash, tx_hash),
        log_idx: log_idx
      }
    end)
  end

  defp render_template_edition(state, contract_pk, template_id, limit) do
    stats_key = Stats.nft_template_tokens_key(contract_pk, template_id)

    if nil != limit or State.exists?(state, Model.Stat, stats_key) do
      state
      |> render_template_edition_limit(limit)
      |> Map.merge(render_template_edition_supply(state, contract_pk, template_id))
    end
  end

  defp render_template_edition_limit(_state, nil), do: %{}

  defp render_template_edition_limit(state, {amount, txi, log_idx}) do
    tx_hash = Txs.txi_to_hash(state, txi)

    %{
      limit: amount,
      limit_log_idx: log_idx,
      limit_tx_hash: encode(:tx_hash, tx_hash)
    }
  end

  defp render_template_edition_supply(state, contract_pk, template_id) do
    {:ok, Model.stat(payload: amount)} =
      State.get(state, Model.Stat, Stats.nft_template_tokens_key(contract_pk, template_id))

    with {:ok, {^contract_pk, ^template_id, _token_id} = prev_key} <-
           State.prev(state, Model.NftTemplateToken, {contract_pk, template_id, nil}),
         {:ok, Model.nft_template_token(txi: txi, log_idx: log_idx)} <-
           State.get(state, Model.NftTemplateToken, prev_key) do
      tx_hash = Txs.txi_to_hash(state, txi)

      %{
        supply: amount,
        supply_log_idx: log_idx,
        supply_tx_hash: encode(:tx_hash, tx_hash)
      }
    else
      _mismatch_or_not_found ->
        %{
          supply: 0,
          supply_log_idx: nil,
          supply_tx_hash: nil
        }
    end
  end

  defp render_owners(state, nft_tokens) do
    Enum.map(nft_tokens, fn {contract_pk, token_id} = key ->
      Model.nft_token_owner(owner: owner_pk) = State.fetch!(state, @owners_table, key)

      %{
        contract_id: encode_contract(contract_pk),
        owner_id: encode_account(owner_pk),
        token_id: token_id
      }
    end)
  end
end

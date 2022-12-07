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
  alias AeMdw.Util
  alias AeMdw.Txs

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
  @type nft :: %{
          :contract_id => String.t(),
          :owner => String.t(),
          :token_id => token_id()
        }

  @ownership_table Model.NftOwnership
  @templates_table Model.NftTemplate
  @owners_table Model.NftTokenOwner

  @spec fetch_nft_owner(pubkey(), token_id()) :: {:ok, pubkey()} | {:error, Error.t()}
  def fetch_nft_owner(contract_pk, token_id) do
    with :ok <- validate_aex141(contract_pk),
         {:ok, {:variant, [0, 1], 1, {{:address, account_pk}}}} <-
           AexnContracts.call_contract(contract_pk, "owner", [token_id]) do
      {:ok, account_pk}
    else
      {:error, exception} ->
        {:error, exception}

      _invalid_call_return ->
        {:error, ErrInput.ContractReturn.exception(value: encode_contract(contract_pk))}
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

  defp deserialize_cursor(Model.NftTokenOwner, cursor_bin64) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64),
         {<<_pk::256>>, token_id} = cursor when is_integer(token_id) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, cursor}
    else
      _invalid -> {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
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
        edition: render_template_edition_limit(state, limit)
      }
    end)
  end

  defp render_template_edition_limit(_state, nil), do: nil

  defp render_template_edition_limit(state, {amount, txi, log_idx}) do
    tx_hash = Txs.txi_to_hash(state, txi)

    %{
      limit: amount,
      limit_log_idx: log_idx,
      limit_tx_hash: encode(:tx_hash, tx_hash)
    }
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

  defp validate_aex141(contract_pk) do
    if AexnContracts.is_aex141?(contract_pk) do
      :ok
    else
      {:error, ErrInput.NotAex141.exception(value: encode_contract(contract_pk))}
    end
  end
end

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

  import AeMdwWeb.Helpers.AexnHelper, only: [enc_ct: 1]

  require Model

  @typep pagination :: Collection.direction_limit()
  @typep cursor() :: binary()

  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @type token_id :: integer()

  @ownership_table Model.NftOwnership

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
        {:error, ErrInput.ContractReturn.exception(value: enc_ct(contract_pk))}
    end
  end

  @spec fetch_owned_nfts(State.t(), pubkey(), cursor(), pagination()) ::
          {:ok, {cursor() | nil, [token_id()], cursor() | nil}} | {:error, Error.t()}
  def fetch_owned_nfts(state, account_pk, cursor, pagination) do
    case deserialize_cursor(cursor) do
      {:ok, cursor_key} ->
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

      {:error, exception} ->
        {:error, exception}
    end
  end

  #
  # Private function
  #
  defp build_streamer(state, table, cursor_key, account_pk) do
    key_boundary = {
      {account_pk, <<>>, nil},
      {account_pk, Util.max_256bit_bin(), Util.max_256bit_int()}
    }

    fn direction ->
      Collection.stream(state, table, direction, key_boundary, cursor_key)
    end
  end

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor({cursor, is_reversed?}),
    do: {cursor |> :erlang.term_to_binary() |> Base.encode64(), is_reversed?}

  defp deserialize_cursor(nil), do: {:ok, nil}

  defp deserialize_cursor(cursor_bin64) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64),
         {<<_pk1::256>>, <<_pk2::256>>, token_id} = cursor when is_integer(token_id) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, cursor}
    else
      _invalid -> {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
    end
  end

  defp render_owned_nfs(nfts) do
    Enum.map(nfts, fn {_owner_pk, contract_pk, token_id} ->
      %{
        contract_id: enc_ct(contract_pk),
        token_id: token_id
      }
    end)
  end

  defp validate_aex141(contract_pk) do
    if AexnContracts.is_aex141?(contract_pk) do
      :ok
    else
      {:error, ErrInput.NotAex141.exception(value: enc_ct(contract_pk))}
    end
  end
end

defmodule AeMdw.Aex141 do
  @moduledoc """
  Context module with AEX141 NFTs.
  """

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db

  import AeMdwWeb.Helpers.AexnHelper, only: [enc_ct: 1]

  require Model

  @type aex141_token() :: map()

  @spec fetch_token(Db.pubkey()) :: {:ok, aex141_token()} | {:error, Error.t()}
  def fetch_token(contract_pk) do
    case Database.fetch(Model.AexnContract, {:aex141, contract_pk}) do
      {:ok, m_aexn} ->
        {:ok, render_token(m_aexn)}

      :not_found ->
        {:error, ErrInput.NotFound.exception(value: enc_ct(contract_pk))}
    end
  end

  #
  # Private functions
  #
  defp render_token(
         Model.aexn_contract(
           index: {:aex141, contract_pk},
           txi: txi,
           meta_info: {name, symbol, base_url, type}
         )
       ) do
    %{
      name: name,
      symbol: symbol,
      base_url: base_url,
      create_txi: txi,
      contract_id: enc_ct(contract_pk),
      metadata_type: type
    }
  end
end

defmodule AeMdw.AexnTokens do
  @moduledoc """
  Context module for AEX-N tokens.
  """

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db

  import AeMdwWeb.Helpers.AexnHelper, only: [enc_ct: 1]
  import AeMdwWeb.AexnView

  require Model

  @type aexn_type() :: :aex9 | :aex141
  @type aexn_token() :: AeMdwWeb.AexnView.aexn_token()

  @spec fetch_token({aexn_type(), Db.pubkey()}) :: {:ok, aexn_token()} | {:error, Error.t()}
  def fetch_token({aexn_type, contract_pk}) when aexn_type in [:aex9, :aex141] do
    case Database.fetch(Model.AexnContract, {aexn_type, contract_pk}) do
      {:ok, m_aexn} ->
        {:ok, render_token(m_aexn)}

      :not_found ->
        {:error, ErrInput.NotFound.exception(value: enc_ct(contract_pk))}
    end
  end
end

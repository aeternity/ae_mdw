defmodule AeMdw.Oracles do
  @moduledoc """
  Context module for dealing with Oracles.
  """

  require AeMdw.Db.Model

  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Mnesia
  alias AeMdw.Node

  @type cursor :: binary()
  # TODO: This needs to be an actual type like AeMdw.Db.Oracle.t()
  @type oracle :: term()
  @typep limit :: pos_integer()

  @table_active AeMdw.Db.Model.ActiveOracle
  @table_active_expiration Model.ActiveOracleExpiration
  @table_inactive AeMdw.Db.Model.InactiveOracle
  @table_inactive_expiration Model.InactiveOracleExpiration

  @spec fetch_active_oracles(Mnesia.direction(), cursor() | nil, limit()) ::
          {[oracle()], cursor() | nil}
  def fetch_active_oracles(direction, cursor, limit) do
    {exp_keys, next_cursor} =
      Mnesia.fetch_keys(
        @table_active_expiration,
        direction,
        deserialize_cursor(cursor),
        limit
      )

    {:ok, {last_gen, -1}} = Mnesia.last_key(AeMdw.Db.Model.Block)

    oracles =
      exp_keys
      |> Enum.map(fn {_expiration, oracle_pk} -> fetch_active_oracle(oracle_pk) end)
      |> render_list(last_gen, true)

    {oracles, serialize_cursor(next_cursor)}
  end

  @spec fetch_inactive_oracles(Mnesia.direction(), cursor() | nil, limit()) ::
          {[oracle()], cursor() | nil}
  def fetch_inactive_oracles(direction, cursor, limit) do
    {exp_keys, next_cursor} =
      Mnesia.fetch_keys(
        @table_inactive_expiration,
        direction,
        deserialize_cursor(cursor),
        limit
      )

    {:ok, {last_gen, -1}} = Mnesia.last_key(AeMdw.Db.Model.Block)

    oracles =
      exp_keys
      |> Enum.map(fn {_expiration, oracle_pk} -> fetch_inactive_oracle(oracle_pk) end)
      |> render_list(last_gen, false)

    {oracles, serialize_cursor(next_cursor)}
  end

  defp render_list(oracles, last_gen, is_active?) do
    Enum.map(oracles, &render(&1, last_gen, is_active?))
  end

  defp render(
         Model.oracle(
           index: pk,
           expire: expire_height,
           register: {{register_height, _mbi}, register_txi},
           extends: extends,
           previous: _previous
         ),
         last_gen,
         is_active?
       ) do
    kbi = min(expire_height - 1, last_gen)

    oracle_tree = AeMdw.Db.Oracle.oracle_tree!({kbi, -1})
    oracle_rec = :aeo_state_tree.get_oracle(pk, oracle_tree)

    %{
      oracle: :aeser_api_encoder.encode(:oracle_pubkey, pk),
      active: is_active?,
      active_from: register_height,
      expire_height: expire_height,
      register: register_txi,
      extends: Enum.map(extends, &Format.bi_txi_txi/1),
      query_fee: Node.Oracle.get!(oracle_rec, :query_fee),
      format: %{
        query: Node.Oracle.get!(oracle_rec, :query_format),
        response: Node.Oracle.get!(oracle_rec, :response_format)
      }
    }
  end

  defp fetch_active_oracle(oracle_pk), do: Mnesia.fetch!(@table_active, oracle_pk)
  defp fetch_inactive_oracle(oracle_pk), do: Mnesia.fetch!(@table_inactive, oracle_pk)

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor({exp_height, oracle_pk}) do
    "#{exp_height}-#{:aeser_api_encoder.encode(:oracle_pubkey, oracle_pk)}"
  end

  defp deserialize_cursor(nil), do: nil

  defp deserialize_cursor(cursor_bin) do
    with [_match0, exp_height, encoded_pk] <- Regex.run(~r/(\d+)-(ok_\w+)/, cursor_bin),
         {:ok, pk} <- :aeser_api_encoder.safe_decode(:oracle_pubkey, encoded_pk) do
      {String.to_integer(exp_height), pk}
    else
      _nil_or_error -> nil
    end
  end
end

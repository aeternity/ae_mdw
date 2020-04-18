defmodule AeMdwWeb.Util do
  alias AeMdw.Db.Model
  alias AeMdw.Db.Stream, as: DBS
  alias :aeser_api_encoder, as: Enc
  require Model

  import AeMdw.{Sigil, Db.Util}

  # frontend sent this, wtf?
  def scope(%{"from" => "undefined", "to" => "undefined"}),
    do: nil

  def scope(%{"from" => from, "to" => to}) do
    [from, to] = Enum.map([from, to], &String.to_integer/1) |> Enum.sort()
    to..from
  end

  def scope(%{}),
    do: nil

  # can be slow, we index the tx type + sender, but checking for receiver is liner
  def spend_txs(sender, receiver),
    do: spend_txs(sender, receiver, Degress)

  def spend_txs(sender, receiver, order) do
    receiver = Enc.encode(:account_pubkey, AeMdw.Validate.id!(receiver))

    DBS.map(
      :forward,
      ~t[object],
      fn x ->
        with :sender_id <- Model.object(x, :role),
             txi <- DBS.Resource.sort_key(Model.object(x, :index)),
             tx <- Model.tx_to_map(read_tx!(txi)),
             ^receiver <- tx["tx"]["recipient_id"] do
          tx
        else
          _ -> nil
        end
      end,
      {sender, :spend_tx},
      order
    )
  end

  def pagination(limit, temp), do: StreamSplit.take_and_drop(temp, limit)

  def pagination(limit, 1, temp), do: pagination(limit, temp)

  def pagination(limit, page, temp) do
    {_, temp1} = StreamSplit.take_and_drop(temp, limit * (page - 1))
    pagination(limit, temp1)
  end

  def pagination(_limit, 0, acc, _temp), do: acc

  def pagination(limit, page, acc, temp) do
    {txs_list, temp1} = StreamSplit.take_and_drop(temp, limit)
    pagination(limit, page - 1, [txs_list | acc], temp1)
  end
end

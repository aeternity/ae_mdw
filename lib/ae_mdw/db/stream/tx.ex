defmodule AeMdw.Db.Stream.Tx do
  require Ex2ms
  require AeMdw.Db.Model

  alias AeMdw.Db.Model

  import AeMdw.{Util, Sigil, Db.Stream.Util}

  @mnesia_chunk_size 20

  def index(),
    do: tx() |> Stream.map(&Model.tx(&1, :index))

  def tx() do
    Stream.resource(
      fn ->
        mspec =
          Ex2ms.fun do
            {:tx, _, _, _} = tx -> tx
          end

        select(~t[tx], mspec, @mnesia_chunk_size)
      end,
      &stream_next/1,
      &id/1
    )
  end

  def rev_index(),
    do: rev_tx() |> Stream.map(&Model.tx(&1, :index))

  def rev_tx() do
    Stream.resource(
      fn ->
        tab = ~t[tx]
        {tab, last(tab)}
      end,
      &rev_stream_next/1,
      &id/1
    )
  end

  ################################################################################

  defp stream_next(:"$end_of_table"), do: {:halt, :done}
  defp stream_next({[tx | txs], cont}), do: {[tx], {txs, cont}}

  defp stream_next({[], cont}) do
    case select(cont) do
      {[tx | txs], cont} -> {[tx], {txs, cont}}
      _ -> {:halt, :done}
    end
  end

  defp rev_stream_next({_, :"$end_of_table"}), do: {:halt, :done}

  defp rev_stream_next({tab, txi}) do
    case read(txi) do
      [tx] -> {[tx], {tab, prev(tab, txi)}}
      [] -> rev_stream_next({tab, prev(tab, txi)})
    end
  end
end

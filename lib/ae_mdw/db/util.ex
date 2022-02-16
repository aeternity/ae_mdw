defmodule AeMdw.Db.Util do
  # credo:disable-for-this-file
  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Database
  alias AeMdw.Txs

  require Logger
  require Model

  import AeMdw.Sigil
  import AeMdw.Util

  @eot :"$end_of_table"

  def read(tab, key),
    do: :mnesia.async_dirty(fn -> Database.read(tab, key) end)

  def read!(tab, key),
    do: read(tab, key) |> one!

  def read_tx(txi) do
    case Database.fetch(~t[tx], txi) do
      {:ok, m_tx} -> [m_tx]
      :not_found -> []
    end
  end

  def read_tx!(txi),
    do: read_tx(txi) |> one!

  def read_block({_, _} = bi) do
    case Database.fetch(~t[block], bi) do
      {:ok, m_block} -> [m_block]
      :not_found -> []
    end
  end

  def read_block(kbi) when is_integer(kbi),
    do: read_block({kbi, -1})

  @spec read_block!(non_neg_integer | {non_neg_integer, integer}) :: Model.block()
  def read_block!(bi),
    do: read_block(bi) |> one!

  def next_bi!({_kbi, _mbi} = bi) do
    {:ok, next_bi} = Database.next_key(Model.Block, bi)
    next_bi
  end

  def next_bi!(kbi) when is_integer(kbi),
    do: next_bi!({kbi, -1})

  def first_txi(),
    do: ensure_key!(~t[tx], :first)

  def last_txi(),
    do: ensure_key!(~t[tx], :last)

  def first_gen(),
    do: ensure_key!(~t[block], :first) |> (fn {h, -1} -> h end).()

  def last_gen(),
    do: ensure_key!(~t[block], :last) |> (fn {h, -1} -> h end).()

  def prev(tab, key) do
    fn -> :mnesia.prev(tab, key) end
    |> :mnesia.async_dirty()
  end

  def next(tab, key) do
    fn -> :mnesia.next(tab, key) end
    |> :mnesia.async_dirty()
  end

  def first(tab) do
    case Database.first_key(tab) do
      {:ok, key} -> key
      :none -> @eot
    end
  end

  def last(tab) do
    case Database.last_key(tab) do
      {:ok, key} -> key
      :none -> @eot
    end
  end

  def select(tab, match_spec) do
    fn -> :mnesia.select(tab, match_spec, :read) end
    |> :mnesia.async_dirty()
  end

  def select(tab, match_spec, chunk_size) do
    fn -> :mnesia.select(tab, match_spec, chunk_size, :read) end
    |> :mnesia.async_dirty()
  end

  def select(cont),
    do: :mnesia.async_dirty(fn -> :mnesia.select(cont) end)

  def count(table),
    do: Database.dirty_all_keys(table) |> length()

  def collect_keys(tab, acc, start_key, next_fn, progress_fn) do
    fn -> do_collect_keys(tab, acc, start_key, next_fn, progress_fn) end
    |> :mnesia.async_dirty()
  end

  def do_collect_keys(tab, acc, start_key, next_fn, progress_fn) do
    case next_fn.(tab, start_key) do
      :"$end_of_table" ->
        acc

      next_key ->
        case progress_fn.(next_key, acc) do
          {:halt, res_acc} -> res_acc
          {:cont, next_acc} -> do_collect_keys(tab, next_acc, next_key, next_fn, progress_fn)
        end
    end
  end

  def do_writes(tab_xs),
    do: do_writes(tab_xs, &Database.write(&1, &2))

  def do_writes(tab_xs, db_write) when is_function(db_write, 2),
    do: Enum.each(tab_xs, fn {tab, xs} -> Enum.each(xs, &db_write.(tab, &1)) end)

  def do_dels(tab_keys),
    do: do_dels(tab_keys, &Database.delete(&1, &2))

  def do_dels(tab_keys, db_delete) when is_function(db_delete, 2),
    do: Enum.each(tab_keys, fn {tab, ks} -> Enum.each(ks, &db_delete.(tab, &1)) end)

  def tx_val(tx_rec, field),
    do: tx_val(tx_rec, elem(tx_rec, 0), field)

  def tx_val(tx_rec, tx_type, field),
    do: elem(tx_rec, Enum.find_index(AeMdw.Node.tx_fields(tx_type), &(&1 == field)) + 1)

  def gen_collect(table, init_key_probe, key_tester, progress, new, add, return) do
    return.(
      case progress.(table, init_key_probe) do
        :"$end_of_table" ->
          new.()

        start_key ->
          case key_tester.(start_key) do
            false ->
              new.()

            other ->
              init_acc =
                case other do
                  :skip -> new.()
                  true -> add.(start_key, new.())
                end

              collect_keys(table, init_acc, start_key, progress, fn key, acc ->
                case key_tester.(key) do
                  false -> {:halt, acc}
                  true -> {:cont, add.(key, acc)}
                  :skip -> {:cont, acc}
                end
              end)
          end
      end
    )
  end

  ##########

  def msecs(msecs) when is_integer(msecs) and msecs > 0, do: msecs
  def msecs(%Date{} = d), do: msecs(date_time(d))
  def msecs(%DateTime{} = d), do: DateTime.to_unix(d) * 1000

  def date_time(%DateTime{} = dt),
    do: dt

  def date_time(msecs) when is_integer(msecs) and msecs > 0,
    do: DateTime.from_unix(div(msecs, 1000)) |> ok!

  def date_time(%Date{} = d) do
    {:ok, dt, 0} = DateTime.from_iso8601(Date.to_iso8601(d) <> " 00:00:00.0Z")
    dt
  end

  def prev_block_type(header) do
    prev_hash = :aec_headers.prev_hash(header)
    prev_key_hash = :aec_headers.prev_key_hash(header)

    cond do
      :aec_headers.height(header) == 0 -> :key
      prev_hash == prev_key_hash -> :key
      true -> :micro
    end
  end

  def proto_vsn(height) do
    hps = AeMdw.Node.height_proto()
    [{vsn, _} | _] = Enum.drop_while(hps, fn {_vsn, min_h} -> height < min_h end)
    vsn
  end

  def block_txi(bi), do: map_one_nil(read_block(bi), &Model.block(&1, :tx_index))

  def block_hash_to_bi(block_hash) do
    case :aec_chain.get_block(block_hash) do
      {:ok, some_block} ->
        {type, header} =
          case some_block do
            {:key_block, header} -> {:key, header}
            {:mic_block, header, _txs, _fraud} -> {:micro, header}
          end

        height = :aec_headers.height(header)

        case height >= last_gen() do
          true ->
            nil

          false ->
            case type do
              :key ->
                {height, -1}

              :micro ->
                collect_keys(Model.Block, nil, {height, <<>>}, &Database.prev_key/2, fn
                  {:ok, {^height, _} = bi}, nil ->
                    Model.block(hash: hash) = read_block!(bi)

                    if hash == block_hash do
                      {:halt, bi}
                    else
                      {:cont, nil}
                    end

                  _k, nil ->
                    {:halt, nil}
                end)
            end
        end

      :error ->
        nil
    end
  end

  @spec gen_to_txi(Blocks.height()) :: Txs.txi()
  def gen_to_txi(gen) do
    case read_block({gen, -1}) do
      [Model.block(tx_index: txi)] ->
        txi

      [] ->
        case Database.last_key(Model.Tx) do
          {:ok, last_txi} -> last_txi + 1
          :none -> 0
        end
    end
  end

  @spec txi_to_gen(Txs.txi()) :: Blocks.height()
  def txi_to_gen(txi) do
    case read_tx(txi) do
      [Model.tx(block_index: {kbi, _mbi})] ->
        kbi

      [] ->
        case Database.last_key(Model.Block) do
          {:ok, {last_kbi, _mbi}} -> last_kbi + 1
          :none -> 0
        end
    end
  end

  #
  # Private functions
  #
  defp ensure_key!(tab, getter) do
    case apply(__MODULE__, getter, [tab]) do
      :"$end_of_table" ->
        raise RuntimeError, message: "can't get #{getter} key for table #{tab}"

      k ->
        k
    end
  end
end

defmodule AeMdw.Db.Stream.Mapper do
  alias AeMdw.Db.{Model, Format}

  require Model

  import AeMdw.{Util, Db.Util}

  ##########

  @tx_tables [Model.Block, Model.Tx, Model.Type, Model.Time, Model.Field]
  def function(format, table) when table in @tx_tables,
    do: compose(formatter(format), &read_tx!/1, &db_txi/1)

  def formatter(:json), do: &Format.to_map/1
  def formatter(:raw), do: &Format.to_raw_map/1
  def formatter(:txi), do: &db_txi/1

  def db_txi({:block, {_height, _mbi}, txi, _hash}), do: txi
  def db_txi({:tx, txi, _hash, {_height, _mbi}, _time}), do: txi
  def db_txi({:type, {_type, txi}, nil}), do: txi
  def db_txi({:time, {_time, txi}, nil}), do: txi
  def db_txi({:field, {_type, _pos, _pk, txi}, nil}), do: txi
  def db_txi({{:tx, txi, _hash, {_height, _mbi}, _time}, _tx_data}), do: txi

end

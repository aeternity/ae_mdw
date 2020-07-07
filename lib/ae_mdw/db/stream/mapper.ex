defmodule AeMdw.Db.Stream.Mapper do
  alias AeMdw.Db.Model
  alias AeMdw.Db.Format

  require Model

  import AeMdw.Db.Util

  ##########

  def function(:json, Model.Block), do: &Format.block_to_map/1
  def function(:json, Model.Tx), do: &Format.tx_to_map/1
  def function(:json, Model.Type), do: &type_to_map/1
  def function(:json, Model.Time), do: &time_to_map/1
  def function(:json, Model.Field), do: &field_to_map/1

  def function(:raw, Model.Block), do: &Format.block_to_raw_map/1
  def function(:raw, Model.Tx), do: &Format.tx_to_raw_map/1
  def function(:raw, Model.Type), do: &type_to_raw_map/1
  def function(:raw, Model.Time), do: &time_to_raw_map/1
  def function(:raw, Model.Field), do: &field_to_raw_map/1

  def function(:txi, Model.Block), do: &Model.block(&1, :tx_index)
  def function(:txi, Model.Tx), do: &tx_txi/1
  def function(:txi, Model.Type), do: &type_txi/1
  def function(:txi, Model.Time), do: &time_txi/1
  def function(:txi, Model.Field), do: &field_txi/1

  def function(f, _tab) when is_function(f, 1), do: f

  ##########

  def type_to_map({:type, {_type, txi}, nil}),
    do: Format.tx_to_map(read_tx!(txi))

  def time_to_map({:time, {_time, txi}, nil}),
    do: Format.tx_to_map(read_tx!(txi))

  def field_to_map({:field, {_type, _pos, _pk, txi}, nil}),
    do: Format.tx_to_map(read_tx!(txi))

  def field_to_map({model_tx, data}),
    do: Format.tx_to_map(model_tx, data)

  def type_to_raw_map({:type, {_type, txi}, nil}),
    do: Format.tx_to_raw_map(read_tx!(txi))

  def time_to_raw_map({:time, {_time, txi}, nil}),
    do: Format.tx_to_raw_map(read_tx!(txi))

  def field_to_raw_map({:field, {_type, _pos, _pk, txi}, nil}),
    do: Format.tx_to_raw_map(read_tx!(txi))

  def field_to_raw_map({model_tx, data}),
    do: Format.tx_to_raw_map(model_tx, data)

  def tx_txi({:tx, txi, _hash, {_kb_index, _mb_index}, _time}), do: txi
  def type_txi({:type, {_type, txi}, nil}), do: txi
  def time_txi({:time, {_time, txi}, nil}), do: txi
  def field_txi({:field, {_type, _pos, _pk, txi}, nil}), do: txi
  def field_txi({model_tx, _data}), do: tx_txi(model_tx)
end

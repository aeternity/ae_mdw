defmodule AeMdw.Db.Stream do
  alias AeMdw.Db.Stream, as: DBS

  import AeMdw.{Sigil, Db.Util}

  ################################################################################

  def block(scope),
    do: map(scope, ~t[block], %{}, Progress)
  def rev_block(scope),
    do: map(scope, ~t[block], %{}, Degress)

  def tx(scope),
    do: map(scope, ~t[tx], %{}, Progress)
  def rev_tx(scope),
    do: map(scope, ~t[tx], %{}, Degress)

  def type_tx(scope, type),
    do: map(scope, ~t[type], %{type: type}, Progress, &as_tx/1)
  def rev_type_tx(scope, type),
    do: map(scope, ~t[type], %{type: type}, Degress, &as_tx/1)

  def object_tx(scope, id),
    do: map(scope, ~t[object], %{id: id}, Progress, &as_tx/1)
  def object_tx(scope, id, type),
    do: map(scope, ~t[object], %{id: id, type: type}, Progress, &as_tx/1)

  def rev_object_tx(scope, id),
    do: map(scope, ~t[object], %{id: id}, Degress, &as_tx/1)
  def rev_object_tx(scope, id, type),
    do: map(scope, ~t[object], %{id: id, type: type}, Degress, &as_tx/1)

  ################################################################################

  def map(scope, tab),
    do: map(scope, tab, %{})
  def map(scope, tab, ctx),
    do: map(scope, tab, ctx, Progress)
  def map(scope, tab, ctx, kind),
    do: map(scope, tab, ctx, kind, &AeMdw.Util.id/1)
  def map(scope, tab, ctx, kind, mapper),
    do: DBS.Resource.map(scope, tab, ctx, kind, mapper)


  def as_tx({:tx, _index, _hash, {_kb_index, _mb_index}} = rec),
    do: rec
  def as_tx({:type, {_type, txi}, nil}),
    do: read_tx!(txi)
  def as_tx({:object, {_type, _pk, txi}, _, _}),
    do: read_tx!(txi)

end

defmodule AeMdwWeb.NameController do
  use AeMdwWeb, :controller

  alias AeMdw.Node, as: AE
  alias AeMdw.Validate
  alias AeMdw.Db.Model
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdwWeb.Continuation, as: Cont
  require Model

  import AeMdwWeb.Util
  import AeMdw.{Sigil, Db.Util}

  ##########

  # expired + claimed
  #def all(conn, %{"owner" => _owner}), do: nil

  def all_direction(conn, %{}),
    do: Cont.response(conn, &json/2, %{fun: :all})

  def all_range(conn, %{}),
    do: Cont.response(conn, &json/2, %{fun: :all})

  # claimed
  #def active(_conn, %{"owner" => _owner}), do: nil

  #def active(_conn, %{}), do: nil


  # name update txs where pointers point to target
  #def pointers(_conn, %{"target" => _target}), do: nil


  #def auctions(_conn, %{}), do: nil


  #def account_bids(_conn, %{"account" => _account}), do: nil


  #def name_bids(_conn, %{"name" => _name}), do: nil





  ##########

  def db_stream(:all, %{"owner" => [owner]}, scope) do
    # owner_pk = Validate.id!(owner)
    # {_, order} = DBS.Scope.scope(scope, Model.Tx, nil)
    # streams = [DBS.map(scope, :json, 'name_claim.account_id': owner_pk)
    #            DBS.map(scope, :json, 'name_transfer.recipient_id': owner_pk)]
    # combined_resource(streams, order, fn tx -> tx["tx_index"] end)
  end

  def db_stream(:all, _params, scope),
    do: DBS.map(scope, :json, type: :name_claim)

  ##########

  def t() do

    pk = <<140, 45, 15, 171, 198, 112, 76, 122, 188, 218, 79, 0, 14, 175, 238, 64, 9, 82, 93, 44, 169, 176, 237, 27, 115, 221, 101, 211, 5, 168, 169, 235>>


    DBS.map(:backward, :json, {:or,
                               ['name_claim.account_id': pk],
                               ['name_transfer.recipient_id': pk]})


  end


end

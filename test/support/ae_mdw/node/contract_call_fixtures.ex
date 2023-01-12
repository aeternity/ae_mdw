defmodule AeMdw.Node.ContractCallFixtures do
  @moduledoc false

  import AeMdw.Node.AexnEventFixtures, only: [aexn_event_hash: 1]

  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @type fname :: String.t()
  @type fun_arg_res :: map()
  @type call_record :: tuple()
  @type event_log :: {pubkey(), [binary()], binary()}

  @spec fun_args_res(fname()) :: %{arguments: list(), function: fname(), result: map()}
  def fun_args_res("mint") do
    %{
      arguments: [
        %{
          type: :address,
          value: "ak_C4UhJiMx2VEPfZ1cBtQCR6wKbA5eTVFa1ohPfuzqQJb4Lyovz"
        },
        %{type: :int, value: 70_000_000_000_000_000_000}
      ],
      function: "mint",
      result: %{type: :unit, value: ""}
    }
  end

  def fun_args_res("burn") do
    %{
      arguments: [%{type: :int, value: 2}],
      function: "burn",
      result: %{type: :unit, value: ""}
    }
  end

  def fun_args_res("transfer") do
    %{
      arguments: [
        %{
          type: :address,
          value: "ak_vPJEUjgtjNZtPy1VstfVTkdbzcsAKK1SEL54wkAKZrghcyESe"
        },
        %{type: :int, value: 2_000_000_000_000_000_000}
      ],
      function: "transfer",
      result: %{type: :unit, value: ""}
    }
  end

  def fun_args_res("transfer_allowance") do
    %{
      arguments: [
        %{
          type: :address,
          value: "ak_2ELPCWzcTdiyYuumjaV4D7kE843d1Ts27zH1Y2LBMKDbNtfq1Q"
        },
        %{
          type: :address,
          value: "ak_taR2fRi3cXYn7a7DaUNcU2KU41psa5JKmhyPC9QcER5T4efqp"
        },
        %{type: :int, value: 1}
      ],
      function: "transfer_allowance",
      result: %{type: :unit, value: ""}
    }
  end

  def fun_args_res("create_pair") do
    %{
      function: "create_pair",
      arguments: [
        %{
          type: "contract",
          value: "ct_djqMe6j8ujtfEdF8pCHXKeRZNjmuwnb1CH2QWbWRR3w514gGD"
        },
        %{
          type: "contract",
          value: "ct_2FyyQBpTyZozQxkHXFiPx7WNNzKBpajDzkzo3SS9cfEPWdG9BM"
        },
        %{
          type: "variant",
          value: [
            1,
            %{
              type: "int",
              value: 1000
            }
          ]
        },
        %{
          type: "variant",
          value: [
            1,
            %{
              type: "int",
              value: 1_636_041_331_999
            }
          ]
        }
      ],
      result: %{
        type: :contract,
        value: "ct_qtPjVVW8FPBuCD4MBQ7yfZgJNThf9owC5emXcnX1mmJfhUAep"
      }
    }
  end

  @spec call_rec(fname()) :: call_record()
  def call_rec("mint") do
    call =
      :aect_call.new(
        :aeser_id.create(
          :account,
          <<177, 109, 71, 150, 121, 127, 54, 94, 201, 60, 70, 245, 34, 29, 197, 129, 184, 20, 45,
            115, 96, 123, 219, 39, 172, 49, 54, 12, 180, 88, 204, 248>>
        ),
        27,
        :aeser_id.create(
          :contract,
          <<108, 159, 218, 252, 142, 182, 31, 215, 107, 90, 189, 201, 108, 136, 21, 96, 45, 160,
            108, 218, 130, 229, 90, 80, 44, 238, 94, 180, 157, 190, 40, 100>>
        ),
        246_949,
        1_000_000_000
      )

    :aect_call.set_log(
      [
        {<<108, 159, 218, 252, 142, 182, 31, 215, 107, 90, 189, 201, 108, 136, 21, 96, 45, 160,
           108, 218, 130, 229, 90, 80, 44, 238, 94, 180, 157, 190, 40, 100>>,
         [
           <<215, 0, 247, 67, 100, 22, 167, 140, 76, 197, 95, 144, 242, 214, 49, 111, 60, 169, 26,
             213, 244, 50, 59, 170, 72, 182, 90, 72, 178, 84, 251, 35>>,
           <<25, 28, 236, 151, 15, 221, 20, 64, 110, 174, 115, 50, 53, 233, 214, 119, 44, 124, 66,
             251, 47, 138, 163, 2, 69, 171, 46, 248, 46, 154, 37, 51>>,
           <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 203, 113,
             245, 31, 197, 88, 0, 0>>
         ], ""}
      ],
      call
    )
  end

  def call_rec("burn") do
    call =
      :aect_call.new(
        :aeser_id.create(
          :account,
          <<234, 90, 164, 101, 3, 211, 169, 40, 246, 51, 6, 203, 132, 12, 34, 114, 203, 201, 104,
            124, 76, 144, 134, 158, 55, 106, 213, 160, 170, 64, 59, 72>>
        ),
        6,
        :aeser_id.create(
          :contract,
          <<99, 147, 221, 52, 149, 77, 197, 100, 5, 160, 112, 15, 89, 26, 213, 27, 12, 179, 74,
            142, 40, 64, 84, 157, 179, 9, 194, 215, 194, 131, 3, 108>>
        ),
        255_795,
        1_000_000_000
      )

    :aect_call.set_log(
      [
        {<<99, 147, 221, 52, 149, 77, 197, 100, 5, 160, 112, 15, 89, 26, 213, 27, 12, 179, 74,
           142, 40, 64, 84, 157, 179, 9, 194, 215, 194, 131, 3, 108>>,
         [
           <<131, 150, 191, 31, 191, 94, 29, 68, 10, 143, 62, 247, 169, 46, 221, 88, 138, 150,
             176, 154, 87, 110, 105, 73, 173, 237, 42, 252, 105, 193, 146, 6>>,
           <<234, 90, 164, 101, 3, 211, 169, 40, 246, 51, 6, 203, 132, 12, 34, 114, 203, 201, 104,
             124, 76, 144, 134, 158, 55, 106, 213, 160, 170, 64, 59, 72>>,
           <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 2>>
         ], ""}
      ],
      call
    )
  end

  def call_rec("transfer") do
    call =
      :aect_call.new(
        :aeser_id.create(
          :account,
          <<25, 28, 236, 151, 15, 221, 20, 64, 110, 174, 115, 50, 53, 233, 214, 119, 44, 124, 66,
            251, 47, 138, 163, 2, 69, 171, 46, 248, 46, 154, 37, 51>>
        ),
        1,
        :aeser_id.create(
          :contract,
          <<108, 159, 218, 252, 142, 182, 31, 215, 107, 90, 189, 201, 108, 136, 21, 96, 45, 160,
            108, 218, 130, 229, 90, 80, 44, 238, 94, 180, 157, 190, 40, 100>>
        ),
        247_411,
        1_000_000_000
      )

    :aect_call.set_log(
      [
        {<<108, 159, 218, 252, 142, 182, 31, 215, 107, 90, 189, 201, 108, 136, 21, 96, 45, 160,
           108, 218, 130, 229, 90, 80, 44, 238, 94, 180, 157, 190, 40, 100>>,
         [
           <<34, 60, 57, 226, 157, 255, 100, 103, 254, 221, 160, 151, 88, 217, 23, 129, 197, 55,
             46, 9, 31, 248, 107, 58, 249, 227, 16, 227, 134, 86, 43, 239>>,
           <<25, 28, 236, 151, 15, 221, 20, 64, 110, 174, 115, 50, 53, 233, 214, 119, 44, 124, 66,
             251, 47, 138, 163, 2, 69, 171, 46, 248, 46, 154, 37, 51>>,
           <<121, 55, 68, 72, 54, 21, 164, 3, 9, 41, 192, 225, 104, 63, 125, 78, 48, 172, 76, 140,
             198, 29, 77, 28, 78, 136, 69, 142, 199, 23, 0, 121>>,
           <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 27, 193, 109,
             103, 78, 200, 0, 0>>
         ], ""}
      ],
      call
    )
  end

  def call_rec("transfer_allowance") do
    {:call,
     <<162, 184, 71, 163, 53, 130, 210, 144, 20, 251, 215, 57, 185, 166, 81, 239, 251, 187, 30,
       186, 34, 211, 212, 22, 71, 5, 65, 145, 142, 106, 218, 131>>,
     {:id, :account,
      <<117, 28, 32, 5, 40, 93, 216, 179, 224, 57, 208, 77, 88, 86, 168, 136, 223, 91, 24, 79,
        252, 100, 141, 144, 124, 117, 91, 41, 115, 208, 244, 74>>}, 63, 258_867,
     {:id, :contract,
      <<172, 5, 106, 9, 237, 151, 96, 29, 163, 211, 165, 245, 93, 176, 93, 128, 24, 160, 13, 118,
        108, 184, 231, 144, 125, 26, 27, 155, 37, 148, 212, 54>>}, 1_000_000_000, 223,
     "YALLOWANCE_NOT_EXISTENT", :revert, []}
  end

  def call_rec("create_pair") do
    call =
      :aect_call.new(
        :aeser_id.create(
          :account,
          <<87, 95, 129, 255, 176, 162, 151, 183, 114, 93, 198, 113, 218, 11, 23, 105, 177, 252,
            92, 190, 69, 56, 92, 123, 90, 209, 252, 46, 175, 29, 96, 157>>
        ),
        41,
        :aeser_id.create(
          :contract,
          <<10, 126, 159, 135, 82, 51, 128, 194, 144, 132, 41, 25, 103, 230, 4, 179, 77, 54, 3,
            118, 14, 88, 180, 200, 222, 12, 124, 138, 3, 39, 137, 110>>
        ),
        577_695,
        1_000_000_000
      )

    :aect_call.set_log(
      [
        {<<10, 126, 159, 135, 82, 51, 128, 194, 144, 132, 41, 25, 103, 230, 4, 179, 77, 54, 3,
           118, 14, 88, 180, 200, 222, 12, 124, 138, 3, 39, 137, 110>>,
         [
           <<165, 104, 218, 83, 242, 206, 42, 48, 134, 199, 10, 251, 46, 174, 228, 68, 181, 162,
             20, 101, 150, 189, 240, 53, 189, 254, 113, 142, 221, 171, 31, 107>>,
           <<83, 107, 86, 97, 199, 199, 69, 232, 131, 106, 241, 190, 181, 55, 62, 215, 254, 27,
             189, 54, 54, 3, 152, 10, 245, 52, 84, 143, 225, 73, 60, 7>>,
           <<165, 183, 23, 114, 145, 239, 159, 199, 241, 17, 145, 38, 165, 16, 97, 176, 78, 150,
             205, 43, 175, 9, 38, 160, 18, 49, 212, 116, 169, 115, 144, 97>>,
           <<111, 0, 117, 208, 6, 235, 44, 43, 240, 108, 173, 15, 111, 153, 4, 169, 116, 46, 60,
             160, 41, 181, 143, 70, 46, 129, 67, 189, 118, 173, 96, 204>>
         ], "1"}
      ],
      call
    )
  end

  @spec call_rec(fname(), {pubkey(), pubkey(), integer}, {pubkey(), pubkey(), integer}) ::
          call_record()
  def call_rec(
        "add_liquidity",
        {remote_pk1, account_pk1, mint_value},
        {remote_pk2, account_pk2, transfer_value}
      ) do
    call =
      :aect_call.new(
        :aeser_id.create(
          :account,
          <<153, 64, 204, 182, 107, 235, 121, 143, 104, 151, 33, 210, 195, 98, 97, 157, 242, 61,
            71, 15, 20, 161, 53, 252, 108, 108, 172, 202, 182, 45, 35, 129>>
        ),
        851,
        :aeser_id.create(
          :contract,
          <<46, 45, 66, 42, 171, 23, 186, 153, 167, 41, 204, 175, 3, 32, 136, 142, 172, 72, 29,
            171, 231, 25, 168, 179, 135, 26, 13, 47, 67, 25, 57, 155>>
        ),
        <<59, 111, 135, 106, 148, 215, 79, 66, 255, 192, 111, 136, 27, 193, 109, 103, 78, 199,
          255, 192, 111, 136, 3, 102, 59, 203, 87, 244, 146, 201, 32, 32>>,
        633_129,
        1_000_000_000
      )

    :aect_call.set_log(
      [
        {remote_pk1,
         [
           <<168, 150, 230, 248, 242, 47, 81, 142, 59, 217, 89, 130, 144, 3, 40, 124, 246, 97,
             159, 14, 37, 152, 69, 37, 7, 43, 6, 144, 110, 218, 143, 46>>,
           <<46, 45, 66, 42, 171, 23, 186, 153, 167, 41, 204, 175, 3, 32, 136, 142, 172, 72, 29,
             171, 231, 25, 168, 179, 135, 26, 13, 47, 67, 25, 57, 155>>,
           <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 27, 193, 109,
             103, 78, 200, 0, 0>>,
           <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 106, 148,
             215, 79, 67, 0, 0>>
         ], ""},
        {remote_pk1,
         [
           <<54, 4, 49, 94, 171, 25, 183, 10, 20, 145, 116, 243, 246, 190, 127, 103, 37, 247, 252,
             73, 166, 113, 182, 0, 236, 231, 26, 173, 216, 245, 249, 42>>,
           <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 27, 193, 109,
             103, 78, 200, 0, 0>>,
           <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 106, 148,
             215, 79, 67, 0, 0>>
         ], ""},
        {remote_pk1,
         [
           aexn_event_hash(:mint),
           account_pk1,
           <<mint_value::256>>
         ], ""},
        {remote_pk2,
         [
           <<117, 180, 225, 85, 86, 76, 112, 120, 101, 246, 89, 142, 64, 13, 74, 204, 168, 32,
             243, 102, 226, 198, 233, 26, 27, 45, 226, 54, 200, 10, 120, 85>>,
           <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 3, 232>>
         ], ""},
        {remote_pk2,
         [
           aexn_event_hash(:transfer),
           remote_pk2,
           account_pk2,
           <<transfer_value::256>>
         ], ""}
      ],
      call
    )
  end

  @spec call_rec(fname(), pubkey()) :: call_record()
  def call_rec("attach", account_pk) do
    contract_pk = <<2::256>>

    :aect_call.new(
      :aeser_id.create(:account, account_pk),
      2,
      :aeser_id.create(:contract, contract_pk),
      1,
      1_000_000_000
    )
  end

  def call_rec("paying_for", account_pk) do
    contract_pk = <<123::256>>

    :aect_call.new(
      :aeser_id.create(:account, account_pk),
      2,
      :aeser_id.create(:contract, contract_pk),
      1,
      1_000_000_000
    )
  end

  @spec call_rec(fname(), pubkey(), AeMdw.Blocks.height(), pubkey(), [event_log()]) ::
          call_record()
  def call_rec(fname, contract_pk, height, event_pk, extra_logs \\ [])

  def call_rec("transfer", contract_pk, height, event_pk, extra_logs) do
    call =
      :aect_call.new(
        :aeser_id.create(:account, <<1::256>>),
        2,
        :aeser_id.create(:contract, contract_pk),
        height,
        1_000_000_000
      )

    :aect_call.set_log(
      [
        {event_pk, [aexn_event_hash(:transfer), <<1::256>>, <<2::256>>, <<10_000::256>>], <<>>}
      ] ++
        extra_logs,
      call
    )
  end

  def call_rec("logs", contract_pk, height, nil, logs) do
    call =
      :aect_call.new(
        :aeser_id.create(:account, <<2::256>>),
        2,
        :aeser_id.create(:contract, contract_pk),
        <<1::256>>,
        height,
        1_000_000_000
      )

    :aect_call.set_log(logs, call)
  end

  def call_rec("remote_log", contract_pk, height, remote_pk, extra_logs) do
    {:call,
     <<7, 3, 220, 129, 25, 69, 185, 205, 148, 53, 54, 115, 161, 72, 225, 149, 238, 18, 80, 50,
       185, 167, 125, 140, 71, 128, 149, 100, 229, 81, 223, 196>>, {:id, :account, <<1::256>>},
     41, height, {:id, :contract, contract_pk}, 1_000_000_000, 22_929,
     <<159, 2, 160, 111, 0, 117, 208, 6, 235, 44, 43, 240, 108, 173, 15, 111, 153, 4, 169, 116,
       46, 60, 160, 41, 181, 143, 70, 46, 129, 67, 189, 118, 173, 96, 204>>, :ok,
     [
       {remote_pk,
        [
          <<165, 104, 218, 83, 242, 206, 42, 48, 134, 199, 10, 251, 46, 174, 228, 68, 181, 162,
            20, 101, 150, 189, 240, 53, 189, 254, 113, 142, 221, 171, 31, 107>>,
          <<83, 107, 86, 97, 199, 199, 69, 232, 131, 106, 241, 190, 181, 55, 62, 215, 254, 27,
            189, 54, 54, 3, 152, 10, 245, 52, 84, 143, 225, 73, 60, 7>>
        ], "1"}
     ] ++
       extra_logs}
  end
end

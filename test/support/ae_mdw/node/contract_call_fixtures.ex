defmodule AeMdw.Node.ContractCallFixtures do
  @moduledoc false

  @type fname() :: String.t()
  @type fun_arg_res() :: map()
  @type call_record() :: tuple()

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

  @spec call_rec(fname()) :: call_record()
  def call_rec("mint") do
    {:call,
     <<212, 32, 3, 205, 108, 129, 181, 165, 13, 42, 87, 221, 175, 30, 4, 160, 182, 188, 22, 221,
       238, 38, 181, 71, 183, 109, 12, 174, 6, 43, 7, 223>>,
     {:id, :account,
      <<177, 109, 71, 150, 121, 127, 54, 94, 201, 60, 70, 245, 34, 29, 197, 129, 184, 20, 45, 115,
        96, 123, 219, 39, 172, 49, 54, 12, 180, 88, 204, 248>>}, 27, 246_949,
     {:id, :contract,
      <<108, 159, 218, 252, 142, 182, 31, 215, 107, 90, 189, 201, 108, 136, 21, 96, 45, 160, 108,
        218, 130, 229, 90, 80, 44, 238, 94, 180, 157, 190, 40, 100>>}, 1_000_000_000, 2413, "?",
     :ok,
     [
       {<<108, 159, 218, 252, 142, 182, 31, 215, 107, 90, 189, 201, 108, 136, 21, 96, 45, 160,
          108, 218, 130, 229, 90, 80, 44, 238, 94, 180, 157, 190, 40, 100>>,
        [
          <<215, 0, 247, 67, 100, 22, 167, 140, 76, 197, 95, 144, 242, 214, 49, 111, 60, 169, 26,
            213, 244, 50, 59, 170, 72, 182, 90, 72, 178, 84, 251, 35>>,
          <<25, 28, 236, 151, 15, 221, 20, 64, 110, 174, 115, 50, 53, 233, 214, 119, 44, 124, 66,
            251, 47, 138, 163, 2, 69, 171, 46, 248, 46, 154, 37, 51>>,
          <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 203, 113, 245,
            31, 197, 88, 0, 0>>
        ], ""}
     ]}
  end

  def call_rec("burn") do
    {:call,
     <<75, 198, 182, 80, 179, 91, 73, 12, 46, 250, 26, 167, 237, 91, 109, 38, 24, 22, 142, 158,
       43, 87, 121, 61, 208, 254, 197, 73, 214, 131, 249, 230>>,
     {:id, :account,
      <<234, 90, 164, 101, 3, 211, 169, 40, 246, 51, 6, 203, 132, 12, 34, 114, 203, 201, 104, 124,
        76, 144, 134, 158, 55, 106, 213, 160, 170, 64, 59, 72>>}, 6, 255_795,
     {:id, :contract,
      <<99, 147, 221, 52, 149, 77, 197, 100, 5, 160, 112, 15, 89, 26, 213, 27, 12, 179, 74, 142,
        40, 64, 84, 157, 179, 9, 194, 215, 194, 131, 3, 108>>}, 1_000_000_000, 2960, "?", :ok,
     [
       {<<99, 147, 221, 52, 149, 77, 197, 100, 5, 160, 112, 15, 89, 26, 213, 27, 12, 179, 74, 142,
          40, 64, 84, 157, 179, 9, 194, 215, 194, 131, 3, 108>>,
        [
          <<131, 150, 191, 31, 191, 94, 29, 68, 10, 143, 62, 247, 169, 46, 221, 88, 138, 150, 176,
            154, 87, 110, 105, 73, 173, 237, 42, 252, 105, 193, 146, 6>>,
          <<234, 90, 164, 101, 3, 211, 169, 40, 246, 51, 6, 203, 132, 12, 34, 114, 203, 201, 104,
            124, 76, 144, 134, 158, 55, 106, 213, 160, 170, 64, 59, 72>>,
          <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 2>>
        ], ""}
     ]}
  end

  def call_rec("transfer") do
    {:call,
     <<167, 62, 112, 192, 204, 103, 1, 59, 141, 68, 5, 245, 105, 146, 30, 159, 153, 47, 33, 0, 69,
       184, 159, 210, 204, 20, 111, 1, 145, 139, 242, 76>>,
     {:id, :account,
      <<25, 28, 236, 151, 15, 221, 20, 64, 110, 174, 115, 50, 53, 233, 214, 119, 44, 124, 66, 251,
        47, 138, 163, 2, 69, 171, 46, 248, 46, 154, 37, 51>>}, 1, 247_411,
     {:id, :contract,
      <<108, 159, 218, 252, 142, 182, 31, 215, 107, 90, 189, 201, 108, 136, 21, 96, 45, 160, 108,
        218, 130, 229, 90, 80, 44, 238, 94, 180, 157, 190, 40, 100>>}, 1_000_000_000, 3054, "?",
     :ok,
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
     ]}
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
end

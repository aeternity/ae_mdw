defmodule AeMdwWeb.ContractController do
  use AeMdwWeb, :controller

  # Hardcoded DB only for testing purpose
  @all_contracts [
    %{
      "block_height" => 221_900,
      "contract_id" => "ct_2M2dJU2wLWPE73HpLPmFezqqJbu9PZ8rwKxeDvrids4y1nPYA2",
      "transaction_hash" => "th_PeBFqyFxoMDS31BqSkoMTDCBzxuADWsLqZiWQ6PzufBKq7vFh"
    },
    %{
      "block_height" => 220_862,
      "contract_id" => "ct_6ZuwbMgcNDaryXTnrLMiPFW2ogE9jxAzz1874BToE81ksWek6",
      "transaction_hash" => "th_232Ac5dUNLfBKD77353wpGGBVfLJpvWd13ecHrsz1DVzzZk45E"
    },
    %{
      "block_height" => 218_938,
      "contract_id" => "ct_2AfnEfCSZCTEkxL5Yoi4Yfq6fF7YapHRaFKDJK3THMXMBspp5z",
      "transaction_hash" => "th_6memqAr5S3UQp1pc4FWXT8xUotfdrdUFgBd8VPmjM2ZRuojTF"
    }
  ]

  @txs_for_contract_address %{
    "transactions" => [
      %{
        "block_height" => 221_900,
        "block_hash" => "mh_wVjDD1g6Ci1uy3y9bmzxCvNzWK2gZyAcJicRtTkGtUNGfWAUT",
        "hash" => "th_PeBFqyFxoMDS31BqSkoMTDCBzxuADWsLqZiWQ6PzufBKq7vFh",
        "signatures" => [
          "sg_KJ8L8oE6ron7j5yp9UdTBZuPdVQmvJC9RpoBxjZ6zdSbpmFExZ5axGLAqLjrDVGFwLJz395JfUUkEDEedTB1GxeyQ2eXp"
        ],
        "tx" => %{
          "abi_version" => 3,
          "amount" => 0,
          "call_data" => "cb_KxFE1kQfSxFYQU5BJBFYQU5Br4IAAQEbb4QBQG8AUahQEg==",
          "code" =>
            "cb_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",
          "deposit" => 0,
          "fee" => 141_600_000_000_000,
          "gas" => 1_579_000,
          "gas_price" => 1_000_000_000,
          "nonce" => 1,
          "owner_id" => "ak_cKF1CFBBGTShjap3CnAM4ZvLTLd1UbZNdPCw9AbUwAbxnr9YZ",
          "type" => "ContractCreateTx",
          "version" => 1,
          "vm_version" => 5
        }
      },
      %{
        "block_height" => 221_900,
        "block_hash" => "mh_C3XTsJjMBt4MmodBh7hjkCayACXyya39pY7gBzTAwgLMyVaTL",
        "hash" => "th_cgwYVwtyU9DAQ2beNVKjdrX4M9jNFGU3hpAkVNN5jPCQwPLEA",
        "signatures" => [
          "sg_t7CnyHaBpKyVWfW8dUk3kJnQemgA99iC34U4CfEPDVGJtcYtMXRnuVsLAdzwBJd1BwVRAjPqbD9K17fmf3wv9iV7an7U"
        ],
        "tx" => %{
          "abi_version" => 3,
          "amount" => 0,
          "call_data" =>
            "cb_KxGEoV2hK58AoFAvl8OZXo8AsH6vgl3K4dxm3enrjl1WBySkSGj51Ubpb4IDqEiPA+c=",
          "caller_id" => "ak_cKF1CFBBGTShjap3CnAM4ZvLTLd1UbZNdPCw9AbUwAbxnr9YZ",
          "contract_id" => "ct_2M2dJU2wLWPE73HpLPmFezqqJbu9PZ8rwKxeDvrids4y1nPYA2",
          "fee" => 459_600_000_000_000,
          "gas" => 1_579_000,
          "gas_price" => 1_000_000_000,
          "nonce" => 2,
          "type" => "ContractCallTx",
          "version" => 1
        }
      },
      %{
        "block_height" => 221_900,
        "block_hash" => "mh_YffqXBMVMRpgneDSyWVoGn4u5HBRoTrzbwCR7Xm2EMcWq3GbQ",
        "hash" => "th_wF5d6nKpT8hy3J8CPMBgoS36g6afo2r1kzRV8wUT3HkByZvSG",
        "signatures" => [
          "sg_8VzFrtuzHPbJ3sepRgcMRSUWAEbqTjeV3NVabRb5a54T7ob5We6bdYzX65LPV6Y97xqRHDb7bE9cvJeYuxu7ZbdCtvDsZ"
        ],
        "tx" => %{
          "abi_version" => 3,
          "amount" => 0,
          "call_data" => "cb_KxGEoV2hK58AoEqbAJuWoI/3ipq8OMIJ1cGUOM0el/EBNSG2TGAu6pMOAumCbJk=",
          "caller_id" => "ak_cKF1CFBBGTShjap3CnAM4ZvLTLd1UbZNdPCw9AbUwAbxnr9YZ",
          "contract_id" => "ct_2M2dJU2wLWPE73HpLPmFezqqJbu9PZ8rwKxeDvrids4y1nPYA2",
          "fee" => 459_600_000_000_000,
          "gas" => 1_579_000,
          "gas_price" => 1_000_000_000,
          "nonce" => 3,
          "type" => "ContractCallTx",
          "version" => 1
        }
      }
    ]
  }

  @calls_for_contract_address [
    %{
      "arguments" => %{
        "arguments" => [
          %{
            "type" => "address",
            "value" => "ak_ZrhR41ivuHZgYZfqrLox69dXYWYgvJiCxffVeRBQTiP9w9Uh2"
          },
          %{
            "type" => "int",
            "value" => 1
          }
        ],
        "function" => "transfer"
      },
      "caller_id" => "ak_cKF1CFBBGTShjap3CnAM4ZvLTLd1UbZNdPCw9AbUwAbxnr9YZ",
      "callinfo" => %{
        "caller_id" => "ak_cKF1CFBBGTShjap3CnAM4ZvLTLd1UbZNdPCw9AbUwAbxnr9YZ",
        "caller_nonce" => 3,
        "contract_id" => "ct_2M2dJU2wLWPE73HpLPmFezqqJbu9PZ8rwKxeDvrids4y1nPYA2",
        "gas_price" => 1_000_000_000,
        "gas_used" => 3306,
        "height" => 221_900,
        "log" => [
          %{
            "address" => "ct_2M2dJU2wLWPE73HpLPmFezqqJbu9PZ8rwKxeDvrids4y1nPYA2",
            "data" => "cb_Xfbg4g==",
            "topics" => [
              1.5485047184846566e+76,
              3.626911713574554e+76,
              3.374501628485699e+76,
              1
            ]
          }
        ],
        "return_type" => "ok",
        "return_value" => "cb_P4fvHVw="
      },
      "contract_id" => "ct_2M2dJU2wLWPE73HpLPmFezqqJbu9PZ8rwKxeDvrids4y1nPYA2",
      "result" => %{
        "function" => "transfer",
        "result" => %{
          "type" => "unit",
          "value" => ""
        }
      },
      "transaction_id" => "th_wF5d6nKpT8hy3J8CPMBgoS36g6afo2r1kzRV8wUT3HkByZvSG"
    },
    %{
      "arguments" => %{
        "arguments" => [
          %{
            "type" => "address",
            "value" => "ak_cKF1CFBBGTShjap3CnAM4ZvLTLd1UbZNdPCw9AbUwAbxnr9YZ"
          },
          %{
            "type" => "int",
            "value" => 1000
          }
        ],
        "function" => "transfer"
      },
      "caller_id" => "ak_cKF1CFBBGTShjap3CnAM4ZvLTLd1UbZNdPCw9AbUwAbxnr9YZ",
      "callinfo" => %{
        "caller_id" => "ak_cKF1CFBBGTShjap3CnAM4ZvLTLd1UbZNdPCw9AbUwAbxnr9YZ",
        "caller_nonce" => 2,
        "contract_id" => "ct_2M2dJU2wLWPE73HpLPmFezqqJbu9PZ8rwKxeDvrids4y1nPYA2",
        "gas_price" => 1_000_000_000,
        "gas_used" => 3126,
        "height" => 221_900,
        "log" => [
          %{
            "address" => "ct_2M2dJU2wLWPE73HpLPmFezqqJbu9PZ8rwKxeDvrids4y1nPYA2",
            "data" => "cb_Xfbg4g==",
            "topics" => [
              1.5485047184846566e+76,
              3.626911713574554e+76,
              3.626911713574554e+76,
              1000
            ]
          }
        ],
        "return_type" => "ok",
        "return_value" => "cb_P4fvHVw="
      },
      "contract_id" => "ct_2M2dJU2wLWPE73HpLPmFezqqJbu9PZ8rwKxeDvrids4y1nPYA2",
      "result" => %{
        "function" => "transfer",
        "result" => %{
          "type" => "unit",
          "value" => ""
        }
      },
      "transaction_id" => "th_cgwYVwtyU9DAQ2beNVKjdrX4M9jNFGU3hpAkVNN5jPCQwPLEA"
    }
  ]

  def all_contracts(conn, _params) do
    json(conn, @all_contracts)
  end

  def txs_for_contract_address(conn, _params) do
    json(conn, @txs_for_contract_address)
  end

  def calls_for_contract_address(conn, _params) do
    json(conn, @calls_for_contract_address)
  end

  def verify_contract(conn, params) do
    json(conn, %{body: params})
  end
end

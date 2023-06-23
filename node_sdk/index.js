const {Universal, Node, MemoryAccount, Crypto, AeSdk, CompilerHttp, hash, encode, Encoding, generateKeyPair} = require('@aeternity/aepp-sdk')
const fetch = require('node-fetch')
const fs = require('fs')

const COMPILER_URL = 'https://v7.compiler.aepps.com'

const factorySource = `
contract Example =
  entrypoint example(x : int) = x
main contract Factory =
  stateful entrypoint create() =
    Chain.create() : Example
    Chain.create() : Example
`

const accounts = [
  'ak_tWZrf8ehmY7CyB1JAoBmWJEeThwWnDpU4NadUdzxVSbzDgKjP',
  'ak_2QkttUgEyPixKzqXkJ4LX7ugbRjwCDWPBT4p4M2r8brjxUxUYd',
];
const output = {
  accounts
};

const devModeRequest = async (path) => {
  const response = await fetch(`http://mdw.aeternity.localhost:3313${path}`, {
    headers: {
      'Accept': 'application/json'
    }
  });

  return await response.json();
};

const emitKb = () => devModeRequest('/emit_kb');

const emitMb = () => devModeRequest('/emit_mb');

const main = async () => {
  const keypair = {
    'publicKey': 'ak_tWZrf8ehmY7CyB1JAoBmWJEeThwWnDpU4NadUdzxVSbzDgKjP',
    'secretKey': '7fa7934d142c8c1c944e1585ec700f671cbc71fb035dc9e54ee4fb880edfe8d974f58feba752ae0426ecbee3a31414d8e6b3335d64ec416f3e574e106c7e5412'
  }
  const node = new Node('http://mdw.aeternity.localhost:3013/', { ignoreVersion: true });
  const account = new MemoryAccount(keypair.secretKey);
  const aeSdk = new AeSdk({
    nodes: [{ name: 'devnet', instance: node }],
    accounts: [account],
    onCompiler: new CompilerHttp(COMPILER_URL)
  });
  const factoryContract = await aeSdk.initializeContract({ sourceCode: factorySource });

  // Use client here..
  await emitKb()
  const spend = await aeSdk.spend(100000, accounts[1]);
  await emitKb()

  const contractCreate = await factoryContract.$deploy([]);
  console.log(contractCreate)

  const contract1 = contractCreate.result.contractId;

  const contractCall = await factoryContract.create();
  const contract2 = contractCall.decodedResult;

  output.contracts = [contract1, contract2];

  await emitKb()

  fs.writeFileSync('output.json', JSON.stringify(output));
};

main();

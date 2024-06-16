import { Node, MemoryAccount, AeSdk, CompilerHttp } from '@aeternity/aepp-sdk'
import fs from 'fs'

const COMPILER_URL = 'https://v8.compiler.aepps.com'

const factorySource = `
contract Example =
  entrypoint example(x : int) = x
main contract Factory =
  stateful entrypoint create() =
    Chain.create() : Example
`
const cloneSource = `
contract Example =
  entrypoint example(x : int) = x
main contract CloneFactory =
  stateful entrypoint clone(template : Example) =
    Chain.clone(ref = template) : Example
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
const cloneFactoryContract = await aeSdk.initializeContract({ sourceCode: cloneSource });

// Use client here..
await emitKb()
await aeSdk.spend(100000, accounts[1]);
await emitKb()

const contractCreate = await factoryContract.$deploy([]);
console.log(contractCreate)
const contract1 = contractCreate.result.contractId;

const contractCall1 = await factoryContract.create();
const innerContract1 = contractCall1.decodedResult;

const contractClone = await cloneFactoryContract.$deploy([]);
console.log(contractClone)
const contract2 = contractClone.result.contractId;

const contractCall2 = await cloneFactoryContract.clone(innerContract1);
const innerContract2 = contractCall2.decodedResult;

output.contracts = [contract1, innerContract1, contract2, innerContract2];

await emitKb()

fs.writeFileSync('output.json', JSON.stringify(output));

// replacement for lodash times function in vanilla ES5
export const times = (count, func) => {
  let i = 0
  let per
  let results = []
  count = count || 0
  func = func || function () {}

  // while i is less than len
  while (i < count) {
    per = i / count

    // call function with a custom api that can be
    // used via the this keyword
    results.push(func.call({
      i: i,
      count: count,
      per: per,
      bias: 1 - Math.abs(0.5 - per) / 0.5,
      results: results
    }, i, count, per))
    i += 1
  }
  return results
}

export const transformMetaTx = (txDetails) => {
  return {
    block_height: txDetails.block_height,
    block_hash: txDetails.block_hash,
    gas: txDetails.tx.gas,
    hash: txDetails.hash,
    ga_id: txDetails.tx.ga_id,
    gas_price: txDetails.tx.gas_price,
    fee: txDetails.tx.fee,
    abi_version: txDetails.tx.abi_version,
    auth_data: txDetails.tx.auth_data,
    tx: txDetails.tx.tx.tx
  }
}

export const transformTxType = (transaction) => {
  let txType = transaction.tx.type.replace(/([A-Z])/g, ' $1')
  if (transaction.ga_id) {
    txType += ' (GA)'
  }
  return txType
}

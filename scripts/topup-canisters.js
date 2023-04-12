// Configuration
const dfxJSON = require("../canister_ids.json")
const { exec } = require("node:child_process")

const topUpNumCycles = "2000000000000"
const topUpThreshold = "4000000000000"
const isICMainnet = true
const networkCmd = isICMainnet ? "--network ic" : ""

// Top up cycles for a canister
const topUp = async (canisterName, walletId) => {
  console.info(`Topup Canister: ${canisterName}`)
  return await runCmd(
    `dfx canister ${networkCmd} --wallet ${walletId} deposit-cycles ${topUpNumCycles} ${canisterName}`
  )
}

// Query cycles for the canister
const queryCycles = async canisterName => {
  return await queryCyclesWithStatus(canisterName)
}

// eslint-disable-next-line no-unused-vars
const queryCyclesWithActorBalance = async canisterName => {
  const balance = await runCmd(
    `dfx canister ${networkCmd} call --query ${canisterName} getActorBalance`
  )
  return convertResultToNmber(balance)
}

const queryCyclesWithStatus = async canisterName => {
  console.info(`Query Canister Cycles with status: ${canisterName}`)
  const balance = await runCmd(
    `dfx canister ${networkCmd} status ${canisterName}`
  )
  return convertStatusResultToNmber(balance)
}

const getWalletId = async () => {
  console.info(`Get current identity wallet ID`)
  const result = await runCmd(`dfx identity ${networkCmd} get-wallet`)
  return result.replace(/\n/g, "")
}

const processCanister = async (canisterName, walletId) => {
  try {
    const balance = await queryCycles(canisterName)
    const balanceBN = BigInt(balance)
    const topUpThresholdBN = BigInt(topUpThreshold)

    if (balanceBN <= topUpThresholdBN) {
      console.info(
        `### ${canisterName} Balance  ${balance} <= ${topUpThreshold}, Topping up ${topUpNumCycles} cycles now... ###`
      )
      const result = await topUp(canisterName, walletId)
      console.info(result)

      console.info(`${canisterName} Top Up done`)
    } else {
      console.info(
        `>>> ${canisterName} Balance ${balance} > ${topUpThreshold}, don't need top up <<<`
      )
    }
  } catch (error) {
    console.error(error)
  }
}

const convertResultToNmber = result => {
  const parsed = result.substr(1, result.length - 1)
  const parsedArray = parsed.split(":")
  if (parsedArray.length < 1) {
    return null
  }

  let cycles = parsedArray[0].trim()
  cycles = cycles.replace(/_/g, "")

  return cycles
}

const convertStatusResultToNmber = result => {
  let parsedArray = result.split("\n")
  if (parsedArray.length < 1) {
    return null
  }

  const balString = parsedArray.filter(item => {
    return item.match(/balance/gi) != null
  })

  if (balString.length < 1) return null

  parsedArray = balString[0].split(":")
  if (parsedArray.length < 2) {
    return null
  }

  let cycleString = parsedArray[1]
  cycleString = cycleString.replace("Cycles", "").trim()
  const cycles = cycleString.replace(/_/g, "")
  return cycles
}

const runCmd = cmd => {
  return new Promise((resolve, reject) => {
    exec(cmd, (error, stdout, stderr) => {
      if (error) {
        console.error("could not execute command: ", error)
        reject(stderr)
      } else {
        resolve(stdout ? stdout : stderr)
      }
    })
  })
}

const collectAllCanisters = json => {
  const canisterNameArray = Object.keys(json)
  return canisterNameArray
}

// Process DFX json to find all canisters name, check cycles balance and topUp as needed
const processAllCanisters = async json => {
  console.info("------ Topup Content Fly Canisters ------")
  console.info(`Top Up Threshold: ${topUpThreshold}`)
  const canisterNameArray = collectAllCanisters(json)
  console.info(canisterNameArray)

  const walletId = await getWalletId()
  console.info(`Wallet ID: ${walletId}`)

  const promiseChain = canisterNameArray.reduce((start, next) => {
    return start.then(() => processCanister(next, walletId))
  }, Promise.resolve())

  await promiseChain
}

processAllCanisters(dfxJSON)

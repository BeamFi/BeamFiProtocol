const DFXFile = "../dfx.json"
const dfxJSON = require(DFXFile)
const fs = require("fs").promises

const OutputDFXFile = DFXFile

async function main() {
  dfxJSON["canisters"]["ledger"]["candid"] =
    "backend/remote/icp/ledger.private.did"

  try {
    const content = JSON.stringify(dfxJSON)
    await fs.writeFile(OutputDFXFile, content)
    console.log("Test canisters are added successfully.")
  } catch (error) {
    console.error(error)
    throw error
  }
}

main()

const DFXFile = "../dfx.json"
const dfxJSON = require(DFXFile)
const fs = require("fs").promises

const OutputDFXFile = DFXFile

async function main() {
  dfxJSON["canisters"]["ledger"]["candid"] =
    "backend/remote/ledger/ledger.public.did"

  try {
    const content = JSON.stringify(dfxJSON)
    await fs.writeFile(OutputDFXFile, content)
    console.log("Ledger Candid is updated successfully.")
  } catch (error) {
    console.error(error)
    throw error
  }
}

main()

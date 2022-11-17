# BeamFi Protocol

BeamFi Protocol is a realtime money streaming protocol.

# Folder Structure

backend/service - Motoko Actor Smart Contract where the canister entry point is.  
backend/model - Motoko model types for Beam, BeamOut, Escrow and persistence store helper  
backend/utils - Common utility modules  
diagram - BeamFi architecture (Install Draw.io integration VSCode extension to view it)  
scripts - CI / CD automation scripts

# Dev Process

## Git Branches

dev - all development code will first merge to dev first, any push to dev will trigger deployment to https://dev.beamfi.app  
main - this is where the productuction stable code is, it require manual trigger in Github Action to deploy to https://beamfi.app

## Pull Request & Review

- When working on a new feature, create a new feature branch and work on there.
- When it is ready for testing or review, submit a Pull Request to dev branch.
- The main contributor will review and give feedback.
- When the review is complete, the PR will be merged to dev for testers to try it in frontend
- When it passed the manual human tests, new changes will be merged to main branch and manager can trigger Github Action to deploy to production.

# Quick Start Guide

In summary:

- Setting up your local dev env
- Run local IC replicas
- Deploy local ICP Ledger
- Deploy BeamFI backend Motoko to IC canisters
- Configure local BeamFi app to use local BeamFi canisters
- Test end-to-end integration with frontend

## Background

If this is your first time using Internet Computer, it is highly recommended to read at least these two IC guides to get the basic concepts and experience with running dfx cmd and local IC replicas.

Canisters and code
https://internetcomputer.org/docs/current/concepts/canisters-code

Local development
https://internetcomputer.org/docs/current/developer-docs/quickstart/local-quickstart

## Dev Environment Setup

- Install NodeJS 16.13 or if you have NVM:

```
> nvm use
```

- VSCode

Install Extensions: Prettier, Motoko

- DFX
  Install version 0.11.2 DFX

```
> DFX_VERSION=0.11.2
> sh -ci "$(curl -fsSL https://internetcomputer.org/install.sh)"
```

- Vessel - Motoko Package Management Tools  
  Follow the instructions from https://github.com/dfinity/vessel to download and put the binary in your PATH e.g /usr/local/bin .
  Vessel is used to install "matchers" - a Motoko testing library

## Run local IC replicas

Open a separate a new command line Terminal

```
> dfx start
```

## Env Config Setup

To avoid unnecessary direct dependencies in Mototoko Actor for caller permission control, we keep the canister IDs in backend/config/Env.mo which is updated during deployment.

For local development, simply use the preconfigured EnvLocal.txt.

```
> cp guide/EnvLocal.txt backend/config/Env.mo
```

## ICP Ledger

### Local Canister Id setup

This is special step to lock locl ICP ledger canister ID to ryjl3-tyaaa-aaaaa-aaaba-cai for working with Plug Wallet Local network
window.ic.plug.requestTransfer() method.

That piece of code is hardcoded to use canister ID ryjl3-tyaaa-aaaaa-aaaba-cai no matter it's mainnet or local.

In order to get Create Beam working with Plug, a pre-configured canister_ids_local.json is used instead of letting IC local replica to assign one.

Copy it to .dfx/local which is where local IC replicas will store its states and configs.

```
> mkdir .dfx/local
> cp canisters_ids_local.json .dfx/local/canister_ids.json
```

In the next step when ICP ledger is deployed to IC local replicas, it will use the ID stored in canister_ids.json instead of assinging a new one.

### Install Local ICP Ledger

ICP Ledger is a canister configured in dfx.json as custom type.
It will be installed using the WASM file at local/ledger/ledger.wasm.

The detailed guide is here: https://internetcomputer.org/docs/current/developer-docs/integrations/ledger/ledger-local-setup

Assuming a local dfx IC replica is running.

- Update dfx.json ledger config to use private candid for deploying ledger

Open dfx.json
Locate ledger -> candid
Update the value from:

```

backend/remote/ledger/ledger.public.did

```

to

```

backend/remote/ledger/ledger.private.did

```

- Deploy ledger

```

> dfx identity new minter
> dfx identity use minter
> export MINT_ACC=$(dfx ledger account-id)
> dfx identity use default
> export LEDGER_ACC=$(dfx ledger account-id)
> dfx deploy ledger --argument '(record {minting_account = "'${MINT_ACC}'"; initial_values = vec { record { "'${LEDGER_ACC}'"; record { e8s=100_000_000_000 } }; }; send_whitelist = vec {}})'

```

If there is any error when deploying, check the dfx cmd again to make sure single quote and double quote are correct.

- Update dfx.json ledger config to use public candid for building with other canisters

Open dfx.json
Locate ledger -> candid
Update the value to:

```

backend/remote/ledger/ledger.public.did

```

## Build and Deploy Smart Contract to local IC

We will now build and deploy all other Motoko smart contracts to canisters: beam, beamout, beamescrow, monitoringagent
You can find the configurations in dfx.json.

```

> dfx deploy

```

This cmd will take a while to complete.

Note that 'deploy' does both build (~compile) and deploy to IC canisters.
If you want to build only e.g compiling only beamout, try:

```

> dfx build beamout

```

Once it is build, you can find the canister ids in .dfx/local/canister_ids.json .

Be aware that the root canister_ids.json stores the canister ids deployed to IC mainnet.

## Update BeamFi app to use local BeamFi canisters

- copy .dfx/local/canisters_id.json to your local beamapp Git repo .dfx/local/canisters_id.json
- switch to beamapp Git repo, copy env.iclocal to env.development
- run next server

```
> cp env.iclocal env.development
> npm run dev
```

## Testing the end-to-end integration from frontend app

- open http://localhost:3000 in Chrome
- Click "Get Paid" and create a Beam link
- Open the Beam link in new tab

If it works, congratulations! 🎉
You have achieved amazing job!

The next step is to get Create Beam working with local ICP deposit.

# Create Beam with ICP

To Create Beam requires Plug Wallet configured to Local IC network and ICP ledger.

## Plug Wallet

Install Plug Wallet Chrome extension version 0.6.1.2 or higher if you haven't.
https://plugwallet.ooo/

To configure Plug Wallet to use Local ICP Ledger:

- Get the local ICP Ledger canister id

```

> dfx canister id ledger

```

- Click on the network switch button "Mainnet" on top, click "Add" to add a local network.

```

Network Name: Local
Host URL: http://localhost:8000
Ledger Canister Id: {Put the ledger canister id from above}

```

![Add Network](/guide/images/AddNetwork.png)

- Switch to "Local". It should show 0.000 ICP if it works.

![Local Ledger](/guide/images/LocalLedger.png)

More details here: https://medium.com/plugwallet/plug-0-5-3-network-selection-49e105334d83

## Create 2 Accounts

When you install Plug Wallet, one account is created. To test Beam, we need 2 separated accounts.

- Create another account here:

![Create Account](/guide/images/CreateAccount.png)

## Transfer ICP from ICP Mint account to your Plug Wallet

To create Beam, you will need some ICP tokens. When deploying a local ICP ledger above, 100 ICP is minted to the Mint account.

- Switch to minter identity

```
> dfx identity use minter
```

- Get your ledger canister ID

```
dfx canister id ledger
```

- Get your Plug Wallet Account ID
  Open Plug Wallet -> Click Deposit.

Copy Account ID there.

Note: If you wonder what is the difference between Principal ID and Account ID, read this:
https://internetcomputer.org/docs/current/developer-docs/integrations/ledger/#accounts

- Transfer 10 ICP from Mint identity account to your Plug Wallet Account ID 1

```
> dfx ledger transfer --ledger-canister-id {local ledger canister id} --icp 10 {Plug Wallet Account Id} --memo 1

```

## End-to-end Testing

Now, you should have everything you need to create Beam from Beam frontend app.

- open http://localhost:3000 in Chrome
- Click "Create Beam" and follow the instruction to deposit ICP and create beam to another Plug Wallet principal ID
- After the Beam is created sucessfully, go to My Beams:

If you see this and the Beam rate is updating continuously, Congratulations! 🎉

![My Beams](/guide/images/MyBeams.png)

You have achieved incredible job!

# Automated Test

- Escrow Reentrancy test
  backend/test/test-claim-reentrancy.sh

# Local Bitcoin Integration (Future)

BeamEscrow.mo is refactored from Content Fly EscrowPayment.mo which has Bitcoin Testnet Escrow Payment integration.

TODO - Add local Bitcoin configuration guide when we want to integrate Bitcoin to BeamFi frontend.

https://internetcomputer.org/docs/current/developer-docs/integrations/bitcoin/local-development

IC Bitcoin is configured in dfx.json. It's disabled currently.

# Useful Cmds

- Check your identity ledger balance

```

> dfx ledger balance --ledger-canister-id {local ledger canister id}

```

- Transfer ICP from mint account to another account id e.g transger 10 ICP to Plug Wallet Account Id

```

> dfx ledger transfer --ledger-canister-id {local ledger canister id} --icp 10 {Plug Wallet Account Id} --memo 1

```

# Setting up Github Action CI / CD

Get the string using commands below then put it into Github Secrets.
Note: Replace default by the identity name you need.

E.g. icprod

### DFX_IDENTITY

```

awk 'NF {sub(/\r/, ""); printf "%s\\r\\n",$0;}' ~/.config/dfx/identity/icprod/identity.pem

```

### DFX_WALLETS

```

cat ~/.config/dfx/identity/icprod/wallets.json

```

Then replace identity name to "default".

E.g. if the identity name is icprod, change icprod to default in the JSON.

Output:

```
{
  "identities": {
  "icprod": {
    "ic": "xxxxxx"
    }
  }
}
```

Change to:

```
{
  "identities": {
  "default": {
    "ic": "xxxxx"
    }
  }
}
```

# Author

Henry Chan  
henry@beamfi.app  
Twitter: @kinwo

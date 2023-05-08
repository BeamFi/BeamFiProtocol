# Useful Cmds

- Check your identity ledger balance

```

> dfx ledger balance --ledger-canister-id {local ledger canister id}

```

- Transfer ICP from the Mint account to another account id e.g transfer 10 ICP to Plug Wallet Account Id

```

> dfx ledger transfer --ledger-canister-id {local ledger canister id} --icp 10 {Plug Wallet Account Id} --memo 1

```

- Run Bitcoin local daemon

```
./bin/bitcoind -conf=$(pwd)/bitcoin.conf -datadir=$(pwd)/data --port=18444
```

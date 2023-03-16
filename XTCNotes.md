## XTC Commands

### Deposit cycles to mint XTC

```
dfx canister --network=ic call --wallet=$(dfx identity --network=ic get-wallet) --with-cycles 1000000000000 aanaa-xaaaa-aaaah-aaeiq-cai mint "(principal \"2h36r-ahtc2-ia3w3-ogzqm-jspkx-g4w5p-ilylx-ssbay-scl4v-e7l7h-2ae\",0:nat)"
```

(variant { 17_724 = 98_948 : nat })

### Transfer to other

```
dfx canister --network=ic call aanaa-xaaaa-aaaah-aaeiq-cai transferErc20 "(principal \"y3rpf-g74cl-bv6dy-7wsan-cv4cp-ofrsm-ubgyo-mmxfg-lgwp4-pdm4x-nqe\", 800000000000:nat)"
```

(variant { 17_724 = 98_949 : nat })

### Get Transaction Detail

E.g TXID - 98949

```
dfx canister --network=ic call aanaa-xaaaa-aaaah-aaeiq-cai getTransaction "(98949:nat)"
```

### Query balance

```
dfx canister --network=ic call --query aanaa-xaaaa-aaaah-aaeiq-cai balanceOf "(principal \"2h36r-ahtc2-ia3w3-ogzqm-jspkx-g4w5p-ilylx-ssbay-scl4v-e7l7h-2ae\")"
```

### Cycles Format

```
1000000000000
800000000000
```

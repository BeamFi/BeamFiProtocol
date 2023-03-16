#!/usr/bin/env bash

printf "### 🧑‍💻 Test BeamEscrow Creator Claim Funds Reentrancy 🧑‍💻 ###\n\n"

LedgerCanisterId=$(dfx canister id ledger)
EscrowPaymentAccountId=$(dfx ledger account-id --of-canister beamescrow)
BeamJobFlowId="2147483647"

EscrowAmountICP="0.1"
EscrowAmountICPE8S="10000000"
EscrowAmountICPTransferFee="10000"
EscrowAmountICPOffset="0"
CreatorAmountICPOffset="0"
E8SBase="100000000"

BuyerPrincipal=""
BuyerAccountId=
CreatorPrincipal=""
CreatorAccountId=""
DueDate=$(date +"%s")
DueDate=$(echo "($DueDate + 10) * 1000000000" | bc)

EscrowId=""

init() {
  # use default as buyer
  dfx identity use default
  BuyerPrincipal=$(dfx identity get-principal)
  BuyerAccountId=$(dfx ledger account-id)

  #  create creator identity
  dfx identity new creator --disable-encryption
  dfx identity use creator
  CreatorPrincipal=$(dfx identity get-principal)
  CreatorAccountId=$(dfx ledger account-id)

  printf "\n"
}

buyerDeposit() {
  printf "Buyer Deposit started...\n"
  # switch to buyer
  dfx identity use default

  printf "DueDate: $DueDate\n"

  # save buyer current balance
  buyerOrgBalance=$(icpLedgerBalanceE8S $BuyerAccountId)

  # transfer ICP to BeamEscrow
  blockIndex=$(dfx ledger transfer --ledger-canister-id $LedgerCanisterId --amount $EscrowAmountICP --memo $BeamJobFlowId $EscrowPaymentAccountId | sed -n 's/Transfer sent at BlockHeight: \(.*\)/\1/p')
  printf "blockIndex=$blockIndex\n"

  # call beamescrow.createBeamEscrow
  result=$(dfx canister call beamescrow createBeamEscrow "($EscrowAmountICPE8S, variant { icp }, $blockIndex, $DueDate, principal \"$BuyerPrincipal\", principal \"$CreatorPrincipal\")")

  # assert ok
  if [[ $result =~ "ok" ]];
  then
    printf "createBeamEscrow success! 😃\n $result\n"
  else
    printf "createBeamEscrow fails 😭 $result\n"
    exit 1
  fi

  EscrowId=$(echo $result | sed -n 's/.* ok = \(.*\) : .*/\1/p')
  printf "Escrow Id=$EscrowId\n"

  # check beamescrow ledger balance == EscrowAmountICP + EscrowAmountICPOffset
  printf "Checking BeamEscrow ICP\n"
  result=$(icpLedgerBalanceE8S $EscrowPaymentAccountId)
  expected=$(echo "scale=0; (($EscrowAmountICP*$E8SBase) + $EscrowAmountICPOffset)/1" | bc)
  printf "result=$result, expcted=$expected\n"

  if [[ $result == $expected ]];
  then
    printf "BeamEscrow ICP balance is correct! 😃\n"
  else
    printf "BeamEscrow ICP balance is not matched 😭\n"
    exit 1
  fi

  # check buyer ledger balance == Org Balance - EscrowAmountICPE8S
  printf "Checking Buyer ICP\n"
  buyerNewBalance=$(icpLedgerBalanceE8S $BuyerAccountId)
  expected=$(echo "$buyerOrgBalance - $EscrowAmountICPE8S - $EscrowAmountICPTransferFee" | bc)
  printf "buyerNewBalance=$buyerNewBalance, expected=$expected\n"

  if [[ $buyerNewBalance == $expected ]];
  then
    printf "Sender ICP balance is correct! 😃\n"
  else
    printf "Sender ICP balance is not matched 😭\n"
    exit 1
  fi

  printf "\n"
}

icpLedgerBalanceE8S() {
  result=$(dfx ledger balance --ledger-canister-id $LedgerCanisterId $1 | sed -n 's/\(.*\) ICP/\1/p')
  result=$(echo "scale=0; ($result * $E8SBase)/1" | bc)

  echo "$result"
}

creatorClaim() {
  printf "Creator Claim started: escrowId=$EscrowId, $1\n"

  # switch to creator
  dfx identity use creator

  # call creatorClaim
  result=$(dfx canister call beamescrow creatorClaimByPrincipal "($EscrowId, variant { icp }, principal \"$CreatorPrincipal\")")
  printf "$result\n"

  # assert ok
  if [[ $result =~ $1 ]];
  then
    printf "creatorClaim expected result '$1' is passed! 😃\n"
  else
    printf "creatorClaim expected result '$1' fails 😭\n"
    exit 1
  fi

  # check BeamEscrow ledger balance = ICP Offset
  printf "Checking BeamEscrow ICP\n"
  escrowBalance=$(icpLedgerBalanceE8S $EscrowPaymentAccountId)
  expected=$(echo "scale=0; $EscrowAmountICPOffset/1" | bc)
  printf "escrowBalance=$escrowBalance, expcted=$expected\n"

  if [[ $escrowBalance == $expected ]];
  then
    printf "BeamEscrow ICP balance is correct! 😃\n"
  else
    printf "BeamEscrow ICP balance is not matched 😭\n"
    exit 1
  fi

  # check Creator ledger balance = Escrow amount - Transfer fee
  printf "Checking Creator ICP\n"
  creatorNewBalance=$(icpLedgerBalanceE8S $CreatorAccountId)
  expected=$(echo "$EscrowAmountICPE8S - $EscrowAmountICPTransferFee + $CreatorAmountICPOffset" | bc)
  printf "creatorNewBalance=$creatorNewBalance, expected=$expected\n"

  if [[ $creatorNewBalance == $expected ]];
  then
    printf "Creator ICP balance is correct! 😃\n"
  else
    printf "Creator ICP balance is not matched 😭\n"
    exit 1
  fi

  printf "\n"
}

runTest() {
  init
  buyerDeposit
  # sleep to wait for beam to update allocations
  printf "Sleeping to wait for Beam to update creator's allocation\n"
  sleep 20
  creatorClaim "ok"&
  creatorClaim "Nothing to claim"&
}

runTest

exit 0
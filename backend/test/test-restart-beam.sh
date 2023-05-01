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
DueDate=$(echo "($DueDate + 1000) * 1000000000" | bc)

EscrowId=""

init() {
  # use default as buyer
  dfx identity use default
  BuyerPrincipal=$(dfx identity get-principal)
  BuyerAccountId=$(dfx ledger account-id)

  #  create creator identity
  dfx identity new creator --storage-mode=plaintext
  dfx identity use creator
  CreatorPrincipal=$(dfx identity get-principal)
  CreatorAccountId=$(dfx ledger account-id)

  printf "\n"
}

createBeam() {
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
}

icpLedgerBalanceE8S() {
  result=$(dfx ledger balance --ledger-canister-id $LedgerCanisterId $1 | sed -n 's/\(.*\) ICP/\1/p')
  result=$(echo "scale=0; ($result * $E8SBase)/1" | bc)

  echo "$result"
}

stopBeam() {
  myEscrowId=$1
  printf "Stop beam: escrowId=$myEscrowId\n"

  # switch to buyer
  dfx identity use default

  # call stopBeam
  result=$(dfx canister call beam stopBeam "($myEscrowId)")
  printf "$result\n"

  # assert paused
  expectedStatus="paused"
  if [[ $result =~ $expectedStatus ]];
  then
    printf "stopBeam expected result '$expectedStatus' is passed! 😃\n"
  else
    printf "stopBeam expected result '$expectedStatus' fails 😭\n"
    exit 1
  fi

  printf "\n"
}

restartBeam() {
  myEscrowId=$1
  printf "Restart beam: escrowId=$myEscrowId\n"

  # switch to buyer
  dfx identity use default

  # call stopBeam
  result=$(dfx canister call beam restartBeam "($myEscrowId)")
  printf "$result\n"

  # assert active
  expectedStatus="active"
  if [[ $result =~ $expectedStatus ]];
  then
    printf "restartBeam expected result '$expectedStatus' is passed! 😃\n"
  else
    printf "restartBeam expected result '$expectedStatus' fails 😭\n"
    exit 1
  fi

  printf "\n"
}

checkCreatorClaimable() {
  myEscrowId=$1
  result=$(dfx canister call beamescrow queryMyBeamEscrow "($myEscrowId)")

  claimable=$(echo $result | sed -n 's/.* creatorClaimable = \(.*\) : .*/\1/p')
  claimable=$(echo $claimable | sed 's/_//g')
  echo "$claimable"
}

runCheckClaimable() {
  claimable=$(checkCreatorClaimable 8)
  echo "$claimable"
}

showBeamByEscrowId() {
  myEscrowId=$1
  result=$(dfx canister call beam queryBeamByEscrowIds "(vec{$myEscrowId})")
  echo "$result"
}

runTest() {
  init
  createBeam
  
  # sleep to wait for beam to update allocations
  printf "Sleeping to wait for Beam to update creator's allocation\n"
  sleep 30

  # stop beam
  stopBeam $EscrowId

  showBeamByEscrowId $EscrowId

  # check and note BeamEscrow creatorClaimable and set to claimable
  claimable=$(checkCreatorClaimable $EscrowId)

  # sleep to wait for beam (in case beam hasn't been stopped)
  printf "Sleeping to wait for Beam to update creator's allocation\n"
  sleep 30

  # check again BeamEscrow creatorClaimable and set to claimableAfterStop
  claimableAfterStop=$(checkCreatorClaimable $EscrowId)

  # if beam has stopped, there should be no change in creatorClaimable
  if [[ $claimable -eq $claimableAfterStop ]];
  then
    printf "Beam has stopped correctly 😃\n"
  else
    printf "Beam hasn't stopped 😭, claimable=$claimable, claimableAfterStop=$claimableAfterStop\n"
    exit 1
  fi

  # restart beam
  restartBeam $EscrowId

  showBeamByEscrowId $EscrowId

  # sleep to wait for beam to stream
  printf "Sleeping to wait for Beam to update creator's allocation\n"
  sleep 30

  # check again BeamEscrow creatorClaimable and set to claimableAfterRestart
  claimableAfterRestart=$(checkCreatorClaimable $EscrowId)

  # if beam has restarted, claimableAfterRestart should be bigger than claimableAfterStop
  if [[ $claimableAfterRestart -gt $claimableAfterStop ]];
  then
    printf "Beam has restarted correctly, claimable after restart is bigger than before it 😃\n"
  else
    printf "Beam hasn't restarted 😭, claimable after restart is smaller than or equal to before it, claimableAfterRestart=$claimableAfterRestart, claimableAfterStop=$claimableAfterStop\n"
    exit 1
  fi
}

runTest

exit 0
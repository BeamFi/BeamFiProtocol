#!/usr/bin/env bash

dfx canister create beamescrow
dfx canister create beam

BeamEscrowCanisterId=$(dfx canister id beamescrow)
BeamCanisterId=$(dfx canister id beam)

printf "export BEAM_ESCROW_CANISTER_ID=$BeamEscrowCanisterId\n"
echo "BEAM_ESCROW_CANISTER_ID=$BeamEscrowCanisterId" >> $GITHUB_ENV

printf "export BEAM_CANISTER_ID=$BeamCanisterId\n"
echo "BEAM_CANISTER_ID=$BeamCanisterId" >> $GITHUB_ENV

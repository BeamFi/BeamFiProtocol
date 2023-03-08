import Ledger "canister:ledger";

import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Cycles "mo:base/ExperimentalCycles";
import Int "mo:base/Int";
import List "mo:base/List";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import R "mo:base/Result";
import T "mo:base/Time";
import Trie "mo:base/Trie";

import BitcoinApi "../bitcoin/BitcoinApi";
import BitcoinType "../bitcoin/BitcoinType";
import BitcoinUtils "../bitcoin/BitcoinUtils";
import BitcoinWallet "../bitcoin/BitcoinWallet";
import Env "../config/Env";
import BeamType "../model/beam/BeamType";
import EscrowStoreHelper "../model/escrow/EscrowStoreHelper";
import EscrowType "../model/escrow/EscrowType";
import Account "../model/ledger/Account";
import Err "../utils/Error";
import Guard "../utils/Guard";
import Op "../utils/Operation";

actor BeamEscrow {

  type EscrowId = EscrowType.EscrowId;
  type EscrowContract = EscrowType.EscrowContract;
  type BeamEscrowContract = EscrowType.BeamEscrowContract;
  type TokenType = EscrowType.TokenType;
  type TokenAmount = EscrowType.TokenAmount;
  type BlockIndex = EscrowType.BlockIndex;
  type Allocation = EscrowType.Allocation;
  type EscrowPaymentType = EscrowType.EscrowPaymentType;
  type BeamEscrowPPStore = EscrowType.BeamEscrowPPStore;
  type ClaimEffectResult = EscrowType.ClaimEffectResult;

  // --- Bitcoin
  type BitcoinAddress = BitcoinType.BitcoinAddress;
  type Satoshi = BitcoinType.Satoshi;
  type Network = BitcoinType.Network;
  type SendRequest = BitcoinType.SendRequest;
  // ---

  type Period = BeamType.Period;
  type BeamId = BeamType.BeamId;
  type BeamRelationObjId = BeamType.BeamRelationObjId;

  type ErrorCode = Err.ErrorCode;

  type AccountIdentifier = Account.AccountIdentifier;

  type Time = T.Time;

  type Result<Ok, Err> = R.Result<Ok, Err>;

  stable var escrowStore : Trie.Trie<EscrowId, EscrowContract> = Trie.empty();
  stable var beamEscrowPPStore : BeamEscrowPPStore = Trie.empty();

  stable var nextEscrowId : EscrowId = 0;
  stable var version : Nat32 = 0;

  // Beam rate in secs
  let beamRate : Period = 2;

  // ICP
  let icpTransferFee : Nat64 = 10_000;
  let require = Guard.require;

  let BeamActor = actor (Env.beamCanisterId) : actor {
    createBeam : (EscrowId, Time, Period) -> async Result<BeamId, BeamType.ErrorCode>;
    createRelationBeam : (EscrowId, Time, Period, BeamRelationObjId) -> async Result<BeamId, BeamType.ErrorCode>
  };

  // Create new EscrowContract with ICP token type and Beam payment type for use in Beam App
  public shared ({ caller }) func createBeamEscrow(
    escrowAmount : TokenAmount,
    blockIndex : BlockIndex,
    dueDate : Time,
    buyerPrincipal : Principal,
    creatorPrincipal : Principal
  ) : async Result<EscrowId, ErrorCode> {

    let createResult = await privateCreateEscrow(
      caller,
      escrowAmount,
      #beam,
      blockIndex,
      dueDate,
      buyerPrincipal,
      creatorPrincipal
    );

    let escrowId = switch createResult {
      case (#err content) return #err(content);
      case (#ok id) id
    };

    let result = await BeamActor.createBeam(escrowId, dueDate, beamRate);
    switch result {
      case (#err content) #err(#escrow_beam_failed(BeamType.errorMesg(content)));
      case (#ok _) #ok(escrowId)
    }
  };

  // Create new EscrowContract with ICP token type and Beam payment type for use in Beam App
  public shared ({ caller }) func createRelationBeamEscrow(
    escrowAmount : TokenAmount,
    blockIndex : BlockIndex,
    dueDate : Time,
    buyerPrincipal : Principal,
    creatorPrincipal : Principal,
    objId : BeamRelationObjId
  ) : async Result<EscrowId, ErrorCode> {

    let createResult = await privateCreateEscrow(
      caller,
      escrowAmount,
      #beam,
      blockIndex,
      dueDate,
      buyerPrincipal,
      creatorPrincipal
    );

    let escrowId = switch createResult {
      case (#err content) return #err(content);
      case (#ok id) id
    };

    let result = await BeamActor.createRelationBeam(escrowId, dueDate, beamRate, objId);
    switch result {
      case (#err content) #err(#escrow_beam_failed(BeamType.errorMesg(content)));
      case (#ok _) #ok(escrowId)
    }
  };

  // Create new EscrowContract with ICP token type
  func privateCreateEscrow(
    caller : Principal,
    escrowAmount : TokenAmount,
    paymentType : EscrowPaymentType,
    blockIndex : BlockIndex,
    dueDate : Time,
    buyerPrincipal : Principal,
    creatorPrincipal : Principal
  ) : async Result<EscrowId, ErrorCode> {

    // Verify BlockIndex with buyerPrincipal and TokenAmount transferred to this canister
    let response = await Ledger.query_blocks({ start = blockIndex; length = 1 });
    let blocksList = List.fromArray(response.blocks);

    // Return error if it is empty blocks, operation.
    if (List.isNil(blocksList)) {
      return #err(#escrow_payment_not_found("The block specified is not found"))
    };

    let blockOp = List.get(blocksList, 0);
    let block = switch blockOp {
      case null return #err(#escrow_payment_not_found("The block specified is not found"));
      case (?myBlock) myBlock
    };

    let isVerified = EscrowType.verifyBlock(block, escrowAmount);
    if (not isVerified) {
      return #err(#escrow_contract_verification_failed("The block is present but it fails verification"))
    };

    // Verify All Contracts ICP + the addition escrowAmount <= actual ICP tokens owned by this canister, requires await
    let canisterICPTokens = await myCanisterBalance(#icp);
    let sumAllEscrowTokenAmount = EscrowStoreHelper.sumAllEscrowTokens(escrowStore, #icp);
    let isMatched = EscrowType.verifyAllEscrowMatchedActual(
      sumAllEscrowTokenAmount + escrowAmount,
      canisterICPTokens.e8s
    );
    if (not isMatched) {
      return #err(#escrow_token_owned_not_matched("The actual ICP owned by the canister is smaller than the total escrow amount of all contracts"))
    };

    // --- Atomicity starts ---
    let escrowId = nextEscrowId;
    nextEscrowId += 1;

    // Create new EscrowContract with #icp token type
    let escrowContract = EscrowType.createEscrowContract(
      escrowId,
      #icp,
      escrowAmount,
      buyerPrincipal,
      creatorPrincipal,
      paymentType
    );

    // Assert EscrowContract invariant
    EscrowType.assertContractInvariant(escrowContract);

    // Add to escrowStore
    escrowStore := EscrowStoreHelper.updateEscrowStore(escrowStore, escrowContract);

    // Add escrowId to beamEscrowPPStore for buyer and creator if the payment type is #beam
    beamEscrowPPStore := EscrowStoreHelper.addEscrowToBeamEscrowPPStore(beamEscrowPPStore, buyerPrincipal, escrowId);
    beamEscrowPPStore := EscrowStoreHelper.addEscrowToBeamEscrowPPStore(beamEscrowPPStore, creatorPrincipal, escrowId);

    // --- Actor state changes commited ---

    #ok(escrowId)
  };

  func creatorClaimCheck(userCaller : Principal, escrowId : EscrowId, tokenType : TokenType) : Result<EscrowContract, EscrowType.ErrorCode> {
    // ----- Checks
    // load the escrow using escrowId
    let opEscrow = EscrowStoreHelper.findEscrowContractById(escrowStore, escrowId);
    let escrowContract = switch opEscrow {
      case null return #err(#escrow_contract_not_found("Escrow Contract not found for the escrowId"));
      case (?myEscrow) myEscrow
    };

    // check caller equals escrow.creatorPrinciapl, else return error
    if (not EscrowType.checkCreatorClaimPermissionAccess(escrowContract, userCaller)) {
      return #err(#escrow_invalid_access("Caller doesn't have access to the Escrow Contract"))
    };

    // check EscrowContract.tokenType is matched
    if (escrowContract.tokenType != tokenType) {
      return #err(#escrow_invalid_token_type("tokenType for claiming is not matched with the EscrowContract"))
    };

    #ok(escrowContract)
  };

  func creatorClaimEffect(escrowContract : EscrowContract, accountId : ?AccountIdentifier, transferFee : TokenAmount) : ClaimEffectResult {
    // --- Atomicity starts ---
    let toBeClaimed = escrowContract.creatorClaimable;
    if (toBeClaimed <= transferFee) {
      return { toBeClaimed = 0; amountMinusFee = 0 }
    };

    let amountMinusFee = toBeClaimed - transferFee;

    // update EscrowContract.creatorAccountIdentifier, updatedAt, creatorClaimable, creatorClaimed
    let newEscrowContract = EscrowType.updateCreatorClaimed(escrowContract, toBeClaimed, accountId);

    // assert invariant
    EscrowType.assertContractInvariant(newEscrowContract);

    // assert valid change
    EscrowType.assertValidContractChange(escrowContract, newEscrowContract);

    // update escrowStore
    escrowStore := EscrowStoreHelper.updateEscrowStore(escrowStore, newEscrowContract);

    // --- Actor state changes commited ---

    { toBeClaimed; amountMinusFee }
  };

  func creatorClaimRollback(res : Result<Text, EscrowType.ErrorCode>, escrowId : EscrowId, toBeClaimed : TokenAmount) : Result<Text, EscrowType.ErrorCode> {
    switch res {
      case (#ok content) #ok(content);
      case (#err content) {
        // Rollback if transfer fails
        // load the escrow again due to reentrancy, the loaded escrowContract above may have changed after transferICPToken
        let opEscrow = EscrowStoreHelper.findEscrowContractById(escrowStore, escrowId);
        let currentEscrowContract = switch opEscrow {
          case null return #err(#escrow_contract_not_found("Escrow Contract not found"));
          case (?myEscrow) myEscrow
        };

        // rollback changes made in Effects using the newly loaded escrowContract
        let rollbackEscrowContract = EscrowType.undoCreatorClaimed(currentEscrowContract, toBeClaimed);

        // update escrowStore
        escrowStore := EscrowStoreHelper.updateEscrowStore(escrowStore, rollbackEscrowContract);

        #err(content)
      }
    };
    // --- Actor state changes commited ---
  };

  // Creator can claim ICP tokens to the default account wallet of their princiapl
  // Follow Checks-Effects-Interactions-Rollback pattern
  // Security Audit: Reentrancy check before / after transferICPToken, multiple parties of the same user can call claim while await transfer is processing
  public shared ({ caller }) func creatorClaimByPrincipal(
    escrowId : EscrowId,
    tokenType : TokenType,
    creatorPrinciapl : Principal
  ) : async Result<Text, EscrowType.ErrorCode> {
    let accountId = Account.accountIdentifier(creatorPrinciapl, Account.defaultSubaccount());
    let checkResult = creatorClaimCheck(caller, escrowId, tokenType);

    let escrowContract = switch checkResult {
      case (#ok myEscrow) myEscrow;
      case (#err content) return #err(content)
    };

    // validate accountId
    if (not Account.validateAccountIdentifier(accountId)) {
      return #err(#escrow_invalid_accountid("accountId for claiming is invalid"))
    };

    // ----- Effects
    let { amountMinusFee; toBeClaimed } = creatorClaimEffect(escrowContract, ?accountId, icpTransferFee);
    if (toBeClaimed == 0) {
      return #ok("Nothing to claim")
    };

    // ----- Interactions for ICP
    // send tokens to the AccountIdentifier based on the caller type
    let memo = Nat64.fromNat(Nat32.toNat(escrowId));
    let res = await transferICPToken(amountMinusFee, icpTransferFee, memo, accountId);
    // Security - note another party can call claim here while transferICPToken is processing

    // ----- Rollback or Success
    creatorClaimRollback(res, escrowId, toBeClaimed)
  };

  // Creator can claim ICP tokens to their wallet
  // Follow Checks-Effects-Interactions-Rollback pattern
  // Security Audit: Reentrancy check before / after transferICPToken, multiple parties of the same user can call claim while await transfer is processing
  public shared ({ caller }) func creatorClaim(
    escrowId : EscrowId,
    tokenType : TokenType,
    accountId : AccountIdentifier
  ) : async Result<Text, EscrowType.ErrorCode> {
    let checkResult = creatorClaimCheck(caller, escrowId, tokenType);
    let escrowContract = switch checkResult {
      case (#ok myEscrow) myEscrow;
      case (#err content) return #err(content)
    };

    // validate accountId
    if (not Account.validateAccountIdentifier(accountId)) {
      return #err(#escrow_invalid_accountid("accountId for claiming is invalid"))
    };

    // ----- Effects
    let { amountMinusFee; toBeClaimed } = creatorClaimEffect(escrowContract, ?accountId, icpTransferFee);
    if (toBeClaimed == 0) {
      return #ok("Nothing to claim")
    };

    // ----- Interactions for ICP
    // send tokens to the AccountIdentifier based on the caller type
    let memo = Nat64.fromNat(Nat32.toNat(escrowId));
    let res = await transferICPToken(amountMinusFee, icpTransferFee, memo, accountId);
    // Security - note another party can call claim here while transferICPToken is processing

    // ----- Rollback or Success
    creatorClaimRollback(res, escrowId, toBeClaimed)
  };

  // Creator can claim ICP tokens to their wallet
  // Follow Checks-Effects-Interactions-Rollback pattern
  // Security Audit: Reentrancy check before / after transferBTCToken, multiple parties of the same user can call claim while await transfer is processing
  public shared ({ caller }) func creatorClaimBTC(
    escrowId : EscrowId,
    tokenType : TokenType,
    btcAddress : BitcoinAddress
  ) : async Result<Text, EscrowType.ErrorCode> {
    let checkResult = creatorClaimCheck(caller, escrowId, tokenType);
    let escrowContract = switch checkResult {
      case (#ok myEscrow) myEscrow;
      case (#err content) return #err(content)
    };

    // ----- Effects
    let btcTransferFee = await calcBTCFees(btcAddress, escrowContract.creatorClaimable);
    let { amountMinusFee; toBeClaimed } = creatorClaimEffect(escrowContract, null, Nat64.fromNat(btcTransferFee));
    if (toBeClaimed == 0) {
      return #ok("Nothing to claim")
    };

    // ----- Interactions for BTC
    let res = await transferBTCToken(btcAddress, amountMinusFee, btcTransferFee);
    // Security - note another party can call claim here while transferBTCToken is processing

    // ----- Rollback or Success
    creatorClaimRollback(res, escrowId, toBeClaimed)
  };

  // Buyer can claim ICP tokens to their wallet when dispute resolution results in buyer funds released
  // Follow Checks-Effects-Interactions-Rollback pattern
  // Security Audit: Reentrancy check before / after transferICPToken, multiple parties of the same user can call claim while await transfer is processing
  public shared ({ caller }) func buyerClaim(escrowId : EscrowId, tokenType : TokenType, accountId : AccountIdentifier) : async Result<Text, EscrowType.ErrorCode> {
    // ----- Checks
    // load the escrow using escrowId
    let opEscrow = EscrowStoreHelper.findEscrowContractById(escrowStore, escrowId);
    let escrowContract = switch opEscrow {
      case null return #err(#escrow_contract_not_found("Escrow Contract not found for the escrowId"));
      case (?myEscrow) myEscrow
    };

    // check caller equals escrow.buyerPrinciapl, else return error
    if (not EscrowType.checkBuyerClaimPermissionAccess(escrowContract, caller)) {
      return #err(#escrow_invalid_access("Caller doesn't have access to the Escrow Contract"))
    };

    // validate accountId
    if (not Account.validateAccountIdentifier(accountId)) {
      return #err(#escrow_invalid_accountid("accountId for claiming is invalid"))
    };

    // check EscrowContract.tokenType is matched
    if (escrowContract.tokenType != tokenType) {
      return #err(#escrow_invalid_token_type("tokenType for claiming is not matched with the EscrowContract"))
    };

    // ----- Effects

    // --- Atomicity starts ---
    let toBeClaimed = escrowContract.buyerClaimable;
    let amountMinusFee = toBeClaimed - icpTransferFee;

    if (toBeClaimed == 0) {
      return #ok("Nothing to claim")
    };

    // update EscrowContract.creatorAccountIdentifier, updatedAt, buyerClaimable, creatorClaimed
    let newEscrowContract = EscrowType.updateBuyerClaimed(escrowContract, toBeClaimed, accountId);

    // assert invariant
    EscrowType.assertContractInvariant(newEscrowContract);
    // assert valid change
    EscrowType.assertValidContractChange(escrowContract, newEscrowContract);

    // update escrowStore
    escrowStore := EscrowStoreHelper.updateEscrowStore(escrowStore, newEscrowContract);

    // --- Actor state changes commited ---

    // ----- Interactions
    // send tokens to the AccountIdentifier based on the caller type
    let memo = Nat64.fromNat(Nat32.toNat(escrowId));
    let res = await transferICPToken(amountMinusFee, icpTransferFee, memo, accountId);
    // Security - note another party can call claim here while transferICPToken is processing

    // ----- Rollback or Success
    switch res {
      case (#ok _) #ok("success");
      case (#err content) {
        // Rollback if transfer fails
        // load the escrow again due to reentrancy, the loaded escrowContract above may have changed after transferICPToken
        let opEscrow = EscrowStoreHelper.findEscrowContractById(escrowStore, escrowId);
        let currentEscrowContract = switch opEscrow {
          case null return #err(#escrow_contract_not_found("Escrow Contract not found for the escrowId"));
          case (?myEscrow) myEscrow
        };

        // rollback changes made in Effects using the newly loaded escrowContract
        let rollbackEscrowContract = EscrowType.undoBuyerClaimed(currentEscrowContract, toBeClaimed);

        // update escrowStore
        escrowStore := EscrowStoreHelper.updateEscrowStore(escrowStore, rollbackEscrowContract);

        #err(content)
      }
    };
    // --- Actor state changes commited ---
  };

  func transferICPToken(transferAmount : TokenAmount, fee : TokenAmount, memo : Nat64, toAccountId : AccountIdentifier) : async Result<Text, EscrowType.ErrorCode> {
    let now = T.now();

    let res = await Ledger.transfer({
      memo = memo;
      from_subaccount = null;
      to = toAccountId;
      amount = { e8s = transferAmount };
      fee = { e8s = fee };
      created_at_time = ?{ timestamp_nanos = Nat64.fromNat(Int.abs(now)) }
    });

    switch (res) {
      case (#Ok(blockIndex)) {
        let mesg = "Paid to " # debug_show toAccountId # " in block " # debug_show blockIndex;
        #ok(mesg)
      };
      case (#Err(#InsufficientFunds { balance })) {
        #err(#escrow_token_transfer_failed("Top me up! The balance is only " # debug_show balance # " e8s"))
      };
      case (#Err(other)) {
        #err(#escrow_token_transfer_failed("Unexpected error: " # debug_show other))
      }
    }
  };

  // Public func - Update escrow contract allocation percentage for escrow, creator and buyer
  // Allocation should be in Nat64 with base 1000000
  public shared ({ caller }) func updateEscrowAllocation(
    escrowId : EscrowId,
    escrowAllocation : Allocation,
    creatorAllocation : Allocation,
    buyerAllocation : Allocation
  ) : async Result<Text, EscrowType.ErrorCode> {
    // require Beam canister for update
    requireEscrowApprovedCanisters(caller);

    privateUpdateEscrowAllocation(caller, escrowId, escrowAllocation, creatorAllocation, buyerAllocation)
  };

  // Update escrow contract allocation percentage for escrow, creator and buyer
  // Allocation should be in Nat64 with base 1000000
  // No await inside
  func privateUpdateEscrowAllocation(
    caller : Principal,
    escrowId : EscrowId,
    escrowAllocation : Allocation,
    creatorAllocation : Allocation,
    buyerAllocation : Allocation
  ) : Result<Text, EscrowType.ErrorCode> {

    // verify escrowAllocation + creatorAllocation + buyerAllocation = 1.0
    if (not EscrowType.verifyAllocations(escrowAllocation, creatorAllocation, buyerAllocation)) {
      return #err(#escrow_invalid_allocations("All allocations should add up to 1.0"))
    };

    // --- Atomicity starts ---
    let escrowContractOp = EscrowStoreHelper.findEscrowContractById(escrowStore, escrowId);
    let escrowContract = switch escrowContractOp {
      case null return #err(#escrow_contract_not_found("The specified escrowId is not found."));
      case (?myEscrow) myEscrow
    };

    // initial new allocations, convert to NAT64
    let initialDeposit = escrowContract.initialDeposit;
    var escrowAmount : TokenAmount = EscrowType.allocateDepositBy(initialDeposit, escrowAllocation);
    var creatorClaimable : TokenAmount = EscrowType.allocateDepositBy(initialDeposit, creatorAllocation);
    var buyerClaimable : TokenAmount = EscrowType.allocateDepositBy(initialDeposit, buyerAllocation);

    // take into account of claimed, avoid overflow
    if (creatorClaimable < escrowContract.creatorClaimed) {
      return #err(#escrow_invalid_allocations("Creator claimable must be larger than or equal to creatorClaimed."))
    };
    creatorClaimable := creatorClaimable - escrowContract.creatorClaimed;

    // take into account of claimed, avoid overflow
    if (buyerClaimable < escrowContract.buyerClaimed) {
      return #err(#escrow_invalid_allocations("Buyer claimable must be larger than or equal to buyerClaimed."))
    };
    buyerClaimable := buyerClaimable - escrowContract.buyerClaimed;

    // update escrowStore
    let newEscrowContract = EscrowType.updateClaimable(escrowContract, escrowAmount, creatorClaimable, buyerClaimable);
    escrowStore := EscrowStoreHelper.updateEscrowStore(escrowStore, newEscrowContract);

    // assert invariant
    EscrowType.assertContractInvariant(newEscrowContract);

    // assert valid change
    EscrowType.assertValidContractChange(escrowContract, newEscrowContract);

    // --- Actor state changes commited ---

    #ok("success")
  };

  // Returns all EscrowContract, only admin manager can access
  public query ({ caller }) func loadAllEscrow(tokenType : TokenType) : async [EscrowContract] {
    requireManager(caller);

    EscrowStoreHelper.loadAllEscrowContract(escrowStore, tokenType)
  };

  public query ({ caller }) func queryMyBeams() : async [BeamEscrowContract] {
    EscrowStoreHelper.loadMyBeams(beamEscrowPPStore, escrowStore, caller)
  };

  public query ({ caller }) func queryMyBeamEscrowBySender(id : EscrowId, sender : Principal) : async Result<BeamEscrowContract, EscrowType.ErrorCode> {
    requireEscrowApprovedCanisters(caller);
    privateQueryMyBeamEscrow(id, sender)
  };

  public query ({ caller }) func queryMyBeamEscrow(id : EscrowId) : async Result<BeamEscrowContract, EscrowType.ErrorCode> {
    privateQueryMyBeamEscrow(id, caller)
  };

  func privateQueryMyBeamEscrow(id : EscrowId, sender : Principal) : Result<BeamEscrowContract, EscrowType.ErrorCode> {
    let result = EscrowStoreHelper.loadMyBeamEscrow(beamEscrowPPStore, escrowStore, sender, id);

    switch result {
      case null #err(#escrow_contract_not_found("Cannot find escrow contract for the id"));
      case (?myEscrow) {
        #ok(myEscrow)
      }
    }
  };

  public query ({ caller }) func sumAllEscrowTokens(tokenType : TokenType) : async TokenAmount {
    requireMonitorAgent(caller);
    EscrowStoreHelper.sumAllEscrowTokens(escrowStore, tokenType)
  };

  // ---- Bitcoin
  /// Returns my Bitcoin balance
  public func getBitcoinBalance() : async Satoshi {
    let network = Env.getBitcoinNetwork();
    let address = await getBitcoinP2pkhAddress();
    await BitcoinApi.get_balance(network, address)
  };

  public func getOtherBitcoinBalance(address : Text) : async Satoshi {
    let network = Env.getBitcoinNetwork();
    await BitcoinApi.get_balance(network, address)
  };

  /// Returns the P2PKH address of this canister at a specific derivation path.
  public func getBitcoinP2pkhAddress() : async BitcoinAddress {
    let network = Env.getBitcoinNetwork();
    let keyName = BitcoinType.getBitcoinKeyName(network);
    await BitcoinWallet.get_p2pkh_address(network, keyName, BitcoinType.DERIVATION_PATH)
  };

  public func verifyBTCDeposit(escrowAmount : TokenAmount) : async Result<Text, ErrorCode> {
    // Verify All Contracts BTC + the addition escrowAmount <= actual BTC tokens owned by this canister, requires await
    let canisterBTCTokens = await getBitcoinBalance();
    let sumAllEscrowTokenAmount = EscrowStoreHelper.sumAllEscrowTokens(escrowStore, #btc);
    let isMatched = EscrowType.verifyAllEscrowMatchedActual(sumAllEscrowTokenAmount + escrowAmount, canisterBTCTokens);
    if (not isMatched) {
      return #err(#escrow_token_owned_not_matched("The actual BTC owned by the canister is smaller than the total escrow amount of all contracts"))
    };

    #ok("verified")
  };

  public shared ({ caller }) func createBTCEscrow(
    escrowAmount : TokenAmount,
    paymentType : EscrowPaymentType,
    dueDate : Time,
    buyerPrincipal : Principal,
    creatorPrincipal : Principal
  ) : async Result<EscrowId, ErrorCode> {

    // --- Atomicity starts ---
    let escrowId = nextEscrowId;
    nextEscrowId += 1;

    // Create new EscrowContract with #btc token type
    let escrowContract = EscrowType.createEscrowContract(
      escrowId,
      #btc,
      escrowAmount,
      buyerPrincipal,
      creatorPrincipal,
      paymentType
    );

    // Assert EscrowContract invariant
    EscrowType.assertContractInvariant(escrowContract);

    // Add to escrowStore
    escrowStore := EscrowStoreHelper.updateEscrowStore(escrowStore, escrowContract);

    // --- Actor state changes commited ---
    #ok(escrowId)
  };

  /// Sends the given amount of bitcoin from this canister to the given address.
  /// Returns the transaction ID.
  func transferBTCToken(destinationAddress : Text, amount : Satoshi, totalFee : Nat) : async Result<Text, EscrowType.ErrorCode> {
    try {
      let network = Env.getBitcoinNetwork();
      let keyName = BitcoinType.getBitcoinKeyName(network);
      let transactionBytes = await BitcoinWallet.send(
        network,
        BitcoinType.DERIVATION_PATH,
        keyName,
        destinationAddress,
        amount,
        totalFee
      );
      let transactionId = BitcoinUtils.bytesToText(transactionBytes);

      #ok(transactionId)
    } catch (error) {
      #err(#escrow_bitcoin_create_transfer_failed("Unknown error is caught in transferBTCToken: " # Error.message(error)))
    }
  };

  func calcBTCFees(destinationAddress : Text, amount : Satoshi) : async Nat {
    let network = Env.getBitcoinNetwork();
    let keyName = BitcoinType.getBitcoinKeyName(network);
    await BitcoinWallet.calc_fees(network, BitcoinType.DERIVATION_PATH, keyName, destinationAddress, amount)
  };
  // ----

  // Returns current balance on the default account of this canister, only admin manager can access
  public shared ({ caller }) func canisterBalance(tokenType : TokenType) : async Ledger.Tokens {
    requireManager(caller);
    await myCanisterBalance(tokenType)
  };

  func myCanisterBalance(tokenType : TokenType) : async Ledger.Tokens {
    switch tokenType {
      case (#icp) await Ledger.account_balance({ account = myAccountId() });
      case (#btc) {
        let amount = await getBitcoinBalance();
        { e8s = amount }
      }
    }
  };

  // Returns canister's default account identifier as a blob.
  public query func canisterAccount() : async AccountIdentifier {
    myAccountId()
  };

  func myAccountId() : AccountIdentifier {
    Account.accountIdentifier(Principal.fromActor(BeamEscrow), Account.defaultSubaccount())
  };

  func requireManager(caller : Principal) : () {
    require(Env.getManager() == caller)
  };

  func requireMonitorAgent(caller : Principal) : () {
    if (caller == Principal.fromText(Env.monitorAgentCanisterId)) {
      return
    };

    assert (false)
  };

  func requireEscrowApprovedCanisters(caller : Principal) : () {
    if (caller == Principal.fromText(Env.beamCanisterId)) {
      return
    };

    assert (false)
  };

  public query func healthCheck() : async Bool {
    true
  };

  public query func canisterVersion() : async Nat32 {
    version
  };

  public query ({ caller }) func getActorBalance() : async Nat {
    requireManager(caller);
    return Cycles.balance()
  };

  public query func getManager() : async Principal {
    Env.getManager()
  };

  public query func getCanisterMemoryInfo() : async Op.CanisterMemoryInfo {
    return Op.getCanisterMemoryInfo()
  };

  // Message Inspection
  type MesgType = {
    // transaction update - non-anonymous, arg principal non-anonymous
    #createBTCEscrow : () -> (
      TokenAmount,
      EscrowPaymentType,
      Time,
      Principal,
      Principal
    );
    #createBeamEscrow : () -> (TokenAmount, BlockIndex, Time, Principal, Principal);
    #createRelationBeamEscrow : () -> (TokenAmount, BlockIndex, Time, Principal, Principal, BeamRelationObjId);
    #buyerClaim : () -> (EscrowId, TokenType, AccountIdentifier);
    #creatorClaim : () -> (EscrowId, TokenType, AccountIdentifier);
    #creatorClaimByPrincipal : () -> (EscrowId, TokenType, Principal);
    #creatorClaimBTC : () -> (EscrowId, TokenType, BitcoinAddress);
    #verifyBTCDeposit : () -> TokenAmount;

    // update type get - non-anonymous, arg size <= 256, 512
    #getBitcoinBalance : () -> ();
    #getBitcoinP2pkhAddress : () -> ();
    #getOtherBitcoinBalance : () -> Text;

    // approved canister update - non-anonymous, arg size <= 512
    #updateEscrowAllocation : () -> (EscrowId, Allocation, Allocation, Allocation);

    // public read - won't invoke inspect
    #canisterAccount : () -> ();
    #canisterVersion : () -> ();
    #getCanisterMemoryInfo : () -> ();
    #getManager : () -> ();
    #healthCheck : () -> ();

    // admin read - won't invoke inspect
    #loadAllEscrow : () -> TokenType;
    #sumAllEscrowTokens : () -> TokenType;
    #canisterBalance : () -> TokenType;
    #getActorBalance : () -> ();

    // owner read - won't invoke inspect
    #queryMyBeamEscrow : () -> EscrowId;
    #queryMyBeamEscrowBySender : () -> (EscrowId, Principal);
    #queryMyBeams : () -> ()
  };

  system func inspect({ arg : Blob; caller : Principal; msg : MesgType }) : Bool {
    switch msg {
      case (#createBTCEscrow n) {
        let (_, _, _, buyerPrinciapl, creatorPrinciapl) = n();
        not Guard.isAnonymous(caller) and not Guard.isAnonymous(buyerPrinciapl) and not Guard.isAnonymous(creatorPrinciapl)
      };
      case (#createBeamEscrow n) {
        let (_, _, _, buyerPrinciapl, creatorPrinciapl) = n();
        not Guard.isAnonymous(caller) and not Guard.isAnonymous(buyerPrinciapl) and not Guard.isAnonymous(creatorPrinciapl)
      };
      case (#createRelationBeamEscrow n) {
        let (_, _, _, buyerPrinciapl, creatorPrinciapl, _) = n();
        not Guard.isAnonymous(caller) and not Guard.isAnonymous(buyerPrinciapl) and not Guard.isAnonymous(creatorPrinciapl)
      };

      case (#buyerClaim _) not Guard.isAnonymous(caller);
      case (#creatorClaim _) not Guard.isAnonymous(caller);
      case (#creatorClaimByPrincipal _) not Guard.isAnonymous(caller);
      case (#creatorClaimBTC _) not Guard.isAnonymous(caller);
      case (#verifyBTCDeposit _) not Guard.isAnonymous(caller) and Guard.withinSize(arg, 256);

      case (#getBitcoinBalance _) Guard.withinSize(arg, 256);
      case (#getBitcoinP2pkhAddress _) Guard.withinSize(arg, 256);
      case (#getOtherBitcoinBalance _) Guard.withinSize(arg, 512);

      case (#updateEscrowAllocation _) not Guard.isAnonymous(caller) and Guard.withinSize(arg, 512);

      case _ true
    }
  };

}

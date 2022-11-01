import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Int64 "mo:base/Int64";
import Float "mo:base/Float";
import Principal "mo:base/Principal";
import Trie "mo:base/Trie";
import Text "mo:base/Text";
import Hash "mo:base/Hash";
import Option "mo:base/Option";
import T "mo:base/Time";
import Order "mo:base/Order";

import Account "../ledger/Account";
import Env "../../config/Env";

// Canister
import Ledger "canister:ledger";

module EscrowType {

  public type EscrowId = Nat32;

  // Percentage in e6s e.g 1000000 = 1.0, 1 = 1/1000000
  public let allocationBase : Nat64 = 1000000;
  public type Allocation = Nat64;

  // e8s token format
  public type TokenAmount = Nat64;
  public type TokenType = { #icp; #btc };
  public type BlockIndex = Nat64;

  type Block = Ledger.Block;

  public type Hash = Hash.Hash;

  type AccountIdentifier = Account.AccountIdentifier;
  type Time = T.Time;

  public type EscrowStore = Trie.Trie<EscrowId, EscrowContract>;
  public type BeamEscrowPPStore = Trie.Trie<Principal, [EscrowId]>;

  public type EscrowPaymentType = { #beam; #lumpSum };

  public type EscrowContract = {
    id : EscrowId;
    tokenType : TokenType;
    initialDeposit : TokenAmount;
    escrowAmount : TokenAmount;
    buyerPrincipal : Principal;
    creatorPrincipal : Principal;
    buyerAccountIdentifier : ?AccountIdentifier;
    creatorAccountIdentifier : ?AccountIdentifier;
    buyerClaimable : TokenAmount;
    creatorClaimable : TokenAmount;
    buyerClaimed : TokenAmount;
    creatorClaimed : TokenAmount;
    paymentType : EscrowPaymentType;
    createdAt : Time;
    updatedAt : Time
  };

  public type ClaimEffectResult = {
    toBeClaimed : TokenAmount;
    amountMinusFee : TokenAmount
  };

  public type BeamEscrowContract = {
    id : EscrowId;
    tokenType : TokenType;
    initialDeposit : TokenAmount;
    escrowAmount : TokenAmount;
    buyerPrincipal : Principal;
    creatorPrincipal : Principal;
    buyerClaimable : TokenAmount;
    creatorClaimable : TokenAmount;
    buyerClaimed : TokenAmount;
    creatorClaimed : TokenAmount;
    createdAt : Time;
    updatedAt : Time
  };

  public type ErrorCode = {
    #escrow_contract_not_found : Text;
    #escrow_contract_verification_failed : Text;
    #escrow_token_owned_not_matched : Text;
    #escrow_payment_not_found : Text;
    #escrow_invalid_allocations : Text;
    #escrow_invalid_access : Text;
    #escrow_invalid_accountid : Text;
    #escrow_invalid_token_type : Text;
    #escrow_token_transfer_failed : Text;
    #escrow_bitcoin_create_transfer_failed : Text
  };

  public func createEscrowContract(
    escrowId : EscrowId,
    tokenType : TokenType,
    escrowAmount : TokenAmount,
    buyerPrincipal : Principal,
    creatorPrincipal : Principal,
    paymentType : EscrowPaymentType
  ) : EscrowContract {
    let now = T.now();
    {
      id = escrowId;
      tokenType = tokenType;
      initialDeposit = escrowAmount;
      escrowAmount = escrowAmount;
      buyerPrincipal = buyerPrincipal;
      creatorPrincipal = creatorPrincipal;
      buyerAccountIdentifier = null;
      creatorAccountIdentifier = null;
      buyerClaimable = 0;
      creatorClaimable = 0;
      buyerClaimed = 0;
      creatorClaimed = 0;
      paymentType = paymentType;
      createdAt = now;
      updatedAt = now
    }
  };

  public func updateClaimable(
    escrow : EscrowContract,
    escrowAmount : TokenAmount,
    creatorClaimable : TokenAmount,
    buyerClaimable : TokenAmount
  ) : EscrowContract {
    let now = T.now();
    {
      id = escrow.id;
      tokenType = escrow.tokenType;
      initialDeposit = escrow.initialDeposit;
      escrowAmount = escrowAmount;
      buyerPrincipal = escrow.buyerPrincipal;
      creatorPrincipal = escrow.creatorPrincipal;
      buyerAccountIdentifier = escrow.buyerAccountIdentifier;
      creatorAccountIdentifier = escrow.creatorAccountIdentifier;
      buyerClaimable = buyerClaimable;
      creatorClaimable = creatorClaimable;
      buyerClaimed = escrow.buyerClaimed;
      creatorClaimed = escrow.creatorClaimed;
      paymentType = escrow.paymentType;
      createdAt = escrow.createdAt;
      updatedAt = now
    }
  };

  public func updateCreatorClaimed(
    escrow : EscrowContract,
    claimedAmount : TokenAmount,
    creatorAccountIdentifier : ?AccountIdentifier
  ) : EscrowContract {
    let now = T.now();
    let newCreatorClaimed = escrow.creatorClaimed + claimedAmount;
    let newCreatorClaimable = escrow.creatorClaimable - claimedAmount;

    {
      id = escrow.id;
      tokenType = escrow.tokenType;
      initialDeposit = escrow.initialDeposit;
      escrowAmount = escrow.escrowAmount;
      buyerPrincipal = escrow.buyerPrincipal;
      creatorPrincipal = escrow.creatorPrincipal;
      buyerAccountIdentifier = escrow.buyerAccountIdentifier;
      creatorAccountIdentifier = creatorAccountIdentifier;
      buyerClaimable = escrow.buyerClaimable;
      creatorClaimable = newCreatorClaimable;
      buyerClaimed = escrow.buyerClaimed;
      creatorClaimed = newCreatorClaimed;
      paymentType = escrow.paymentType;
      createdAt = escrow.createdAt;
      updatedAt = now
    }
  };

  public func updateBuyerClaimed(
    escrow : EscrowContract,
    claimedAmount : TokenAmount,
    creatorAccountIdentifier : AccountIdentifier
  ) : EscrowContract {
    let now = T.now();
    let newBuyerClaimed = escrow.buyerClaimed + claimedAmount;
    let newBuyerClaimable = escrow.buyerClaimable - claimedAmount;

    {
      id = escrow.id;
      tokenType = escrow.tokenType;
      initialDeposit = escrow.initialDeposit;
      escrowAmount = escrow.escrowAmount;
      buyerPrincipal = escrow.buyerPrincipal;
      creatorPrincipal = escrow.creatorPrincipal;
      buyerAccountIdentifier = escrow.buyerAccountIdentifier;
      creatorAccountIdentifier = ?creatorAccountIdentifier;
      buyerClaimable = newBuyerClaimable;
      creatorClaimable = escrow.creatorClaimable;
      buyerClaimed = newBuyerClaimed;
      creatorClaimed = escrow.creatorClaimed;
      paymentType = escrow.paymentType;
      createdAt = escrow.createdAt;
      updatedAt = now
    }
  };

  public func undoCreatorClaimed(escrow : EscrowContract, claimedAmount : TokenAmount) : EscrowContract {
    let now = T.now();
    let newCreatorClaimed = escrow.creatorClaimed - claimedAmount;
    let newCreatorClaimable = escrow.creatorClaimable + claimedAmount;

    {
      id = escrow.id;
      tokenType = escrow.tokenType;
      initialDeposit = escrow.initialDeposit;
      escrowAmount = escrow.escrowAmount;
      buyerPrincipal = escrow.buyerPrincipal;
      creatorPrincipal = escrow.creatorPrincipal;
      buyerAccountIdentifier = escrow.buyerAccountIdentifier;
      creatorAccountIdentifier = escrow.creatorAccountIdentifier;
      buyerClaimable = escrow.buyerClaimable;
      creatorClaimable = newCreatorClaimable;
      buyerClaimed = escrow.buyerClaimed;
      creatorClaimed = newCreatorClaimed;
      paymentType = escrow.paymentType;
      createdAt = escrow.createdAt;
      updatedAt = now
    }
  };

  public func undoBuyerClaimed(escrow : EscrowContract, claimedAmount : TokenAmount) : EscrowContract {
    let now = T.now();
    let newBuyerClaimed = escrow.buyerClaimed - claimedAmount;
    let newBuyerClaimable = escrow.buyerClaimable + claimedAmount;

    {
      id = escrow.id;
      tokenType = escrow.tokenType;
      initialDeposit = escrow.initialDeposit;
      escrowAmount = escrow.escrowAmount;
      buyerPrincipal = escrow.buyerPrincipal;
      creatorPrincipal = escrow.creatorPrincipal;
      buyerAccountIdentifier = escrow.buyerAccountIdentifier;
      creatorAccountIdentifier = escrow.creatorAccountIdentifier;
      buyerClaimable = newBuyerClaimable;
      creatorClaimable = escrow.creatorClaimable;
      buyerClaimed = newBuyerClaimed;
      creatorClaimed = escrow.creatorClaimed;
      paymentType = escrow.paymentType;
      createdAt = escrow.createdAt;
      updatedAt = now
    }
  };

  public func allocateDepositBy(initialDeposit : TokenAmount, percentage : Allocation) : TokenAmount {
    // asset percentage must be positive
    assertNatAllocation(percentage);

    // make sure overflow or underflow will trap instead of wrap
    let allocatedAmount : Nat64 = (initialDeposit * percentage) / allocationBase;
    assertValidAllocatedDeposit(initialDeposit, allocatedAmount);

    return allocatedAmount
  };

  func assertNatAllocation(percentage : Allocation) {
    assert (percentage >= 0 and percentage <= allocationBase)
  };

  func assertValidAllocatedDeposit(initialDeposit : TokenAmount, allocatedAmount : TokenAmount) {
    assert (allocatedAmount >= 0 and allocatedAmount <= initialDeposit)
  };

  public func assertContractInvariant(escrow : EscrowContract) {
    let calcTotal = escrow.escrowAmount + escrow.buyerClaimable + escrow.creatorClaimable + escrow.buyerClaimed + escrow.creatorClaimed;
    assert (calcTotal == escrow.initialDeposit)
  };

  public func assertValidContractChange(old : EscrowContract, new : EscrowContract) {
    // assert same or decreasing escrowAmount
    assert (new.escrowAmount <= old.escrowAmount);
    // assert same or growing creatorClaimed
    assert (new.creatorClaimed >= old.creatorClaimed);
    // assert same or growing buyerClaimed
    assert (new.buyerClaimed >= old.buyerClaimed);

    // assert unchanged: id, tokenType, initialDeposit, buyerPrincipal, creatorPrincipal, buyerAccountIdentifier,
    assert (new.id == old.id);
    assert (new.tokenType == old.tokenType);
    assert (new.initialDeposit == old.initialDeposit);
    assert (new.buyerPrincipal == old.buyerPrincipal);
    assert (new.creatorPrincipal == old.creatorPrincipal);
    assert (new.buyerAccountIdentifier == old.buyerAccountIdentifier);
    assert (new.createdAt == old.createdAt);

    // assert updatedAt is growing
    assert (new.updatedAt >= old.updatedAt)
  };

  // Match means sum <= actual
  public func verifyAllEscrowMatchedActual(sumEscrowTokens : TokenAmount, actualOwned : TokenAmount) : Bool {
    sumEscrowTokens <= actualOwned
  };

  public func verifyBlock(block : Block, escrowAmount : TokenAmount) : Bool {
    let transaction = block.transaction;
    let operationOP = transaction.operation;
    let operation = switch operationOP {
      case null return false;
      case (?myOperation) myOperation
    };

    switch operation {
      case (#Transfer(payload)) {
        // Verified if operation.amount == escrowAmount
        payload.amount.e8s == escrowAmount
      };
      case (#Mint(_)) false;
      case (#Burn(_)) false
    }
  };

  public func verifyAllocations(
    escrowAllocation : Allocation,
    creatorAllocation : Allocation,
    buyerAllocation : Allocation
  ) : Bool {
    let sum = escrowAllocation + creatorAllocation + buyerAllocation;
    sum == allocationBase
  };

  public func hasAllocatedAllToCreator(escrow : EscrowContract) : Bool {
    let creatorOwned = escrow.creatorClaimable + escrow.creatorClaimed;
    creatorOwned == escrow.initialDeposit
  };

  public func checkPermissionAccess(escrow : EscrowContract, caller : Principal) : Bool {
    escrow.buyerPrincipal == caller or escrow.creatorPrincipal == caller
  };

  public func checkCreatorClaimPermissionAccess(escrow : EscrowContract, caller : Principal) : Bool {
    escrow.creatorPrincipal == caller
  };

  public func checkBuyerClaimPermissionAccess(escrow : EscrowContract, caller : Principal) : Bool {
    escrow.buyerPrincipal == caller
  };

  public func errorMesg(errorCode : ErrorCode) : Text {
    switch errorCode {
      case (#escrow_contract_not_found content) content;
      case (#escrow_contract_verification_failed content) content;
      case (#escrow_token_owned_not_matched content) content;
      case (#escrow_payment_not_found content) content;
      case (#escrow_invalid_allocations content) content;
      case (#escrow_invalid_access content) content;
      case (#escrow_invalid_accountid content) content;
      case (#escrow_invalid_token_type content) content;
      case (#escrow_token_transfer_failed content) content;
      case (#escrow_bitcoin_create_transfer_failed content) content
    }
  };

  public func compareByCreatedAt(e1 : EscrowContract, e2 : EscrowContract) : Order.Order {
    if (e1.createdAt < e2.createdAt) {
      return #greater
    };

    if (e1.createdAt > e2.createdAt) {
      return #less
    };

    return #equal
  };

  public func compareByBeamEscrowCreatedAt(e1 : BeamEscrowContract, e2 : BeamEscrowContract) : Order.Order {
    if (e1.createdAt < e2.createdAt) {
      return #greater
    };

    if (e1.createdAt > e2.createdAt) {
      return #less
    };

    return #equal
  };

  public func hash(escrow : EscrowContract) : Hash {
    Text.hash(Nat32.toText(escrow.id))
  };

  public func escrowIdHash(id : EscrowId) : Hash {
    Text.hash(Nat32.toText(id))
  };

  public func escrowIdEqual(id1 : EscrowId, id2 : EscrowId) : Bool {
    id1 == id2
  };

  public func equal(e1 : EscrowContract, e2 : EscrowContract) : Bool {
    e1.id == e2.id
  };

  public func idKey(id : EscrowId) : Trie.Key<EscrowId> { { key = id; hash = Text.hash(Nat32.toText(id)) } };

  public func ppKey(pp : Principal) : Trie.Key<Principal> { { key = pp; hash = Text.hash(Principal.toText(pp)) } };

}

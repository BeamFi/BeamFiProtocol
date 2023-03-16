import ICPLedger "canister:ledger";

import Int "mo:base/Int";
import List "mo:base/List";
import Nat64 "mo:base/Nat64";
import R "mo:base/Result";
import T "mo:base/Time";

import Err "../../utils/Error";
import Account "../icp/Account";
import EscrowType "EscrowType";

module ICP {

  type BlockIndex = EscrowType.BlockIndex;
  type TokenAmount = EscrowType.TokenAmount;

  type AccountIdentifier = Account.AccountIdentifier;

  type ErrorCode = Err.ErrorCode;
  type Result<Ok, Err> = R.Result<Ok, Err>;

  public func verifyBlock(blockIndex : BlockIndex, escrowAmount : TokenAmount) : async Result<BlockIndex, ErrorCode> {
    // Verify BlockIndex with buyerPrincipal and TokenAmount transferred to this canister
    let response = await ICPLedger.query_blocks({ start = blockIndex; length = 1 });
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

    return #ok(blockIndex)
  };

  public func transfer(transferAmount : TokenAmount, fee : TokenAmount, memo : Nat64, toAccountId : AccountIdentifier) : async Result<Text, EscrowType.ErrorCode> {
    let now = T.now();

    let res = await ICPLedger.transfer({
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

}

import Nat64 "mo:base/Nat64";
import R "mo:base/Result";

import XTCActor "../../remote/xtc/XTC";
import Err "../../utils/Error";
import EscrowType "EscrowType";

module XTC {
  type BlockIndex = EscrowType.BlockIndex;
  type TokenAmount = EscrowType.TokenAmount;

  type ErrorCode = Err.ErrorCode;
  type Result<Ok, Err> = R.Result<Ok, Err>;

  public func verifyBlock(blockIndex : BlockIndex, escrowAmount : TokenAmount) : async Result<BlockIndex, ErrorCode> {
    let record = await XTCActor.Actor.getTransaction(Nat64.toNat(blockIndex));
    if (Nat64.fromNat(record.amount) != escrowAmount) {
      return #err(#escrow_contract_verification_failed("The block is present but it fails verification"))
    };

    #ok(blockIndex)
  };

  public func transfer(amount : TokenAmount, to : Principal) : async Result<Text, EscrowType.ErrorCode> {
    let result = await XTCActor.Actor.transferErc20(to, Nat64.toNat(amount));

    switch (result) {
      case (#Ok(txId)) {
        let mesg = "Paid to " # debug_show to # " in transaction " # debug_show txId;
        #ok(mesg)
      };
      case (#Err(other)) {
        #err(#escrow_token_transfer_failed("Unexpected error: " # debug_show other))
      }
    }
  }
}

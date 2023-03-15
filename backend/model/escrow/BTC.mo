import Error "mo:base/Error";
import R "mo:base/Result";

import BitcoinType "../../bitcoin/BitcoinType";
import BitcoinUtils "../../bitcoin/BitcoinUtils";
import BitcoinWallet "../../bitcoin/BitcoinWallet";
import Env "../../config/Env";
import EscrowType "../escrow/EscrowType";

module BTC {

  type Satoshi = BitcoinType.Satoshi;
  type Result<Ok, Err> = R.Result<Ok, Err>;

  // Sends the given amount of bitcoin from this canister to the given address.
  // Returns the transaction ID.
  public func transferBTCToken(destinationAddress : Text, amount : Satoshi, totalFee : Nat) : async Result<Text, EscrowType.ErrorCode> {
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

  public func calcBTCFees(destinationAddress : Text, amount : Satoshi) : async Nat {
    let network = Env.getBitcoinNetwork();
    let keyName = BitcoinType.getBitcoinKeyName(network);
    await BitcoinWallet.calc_fees(network, BitcoinType.DERIVATION_PATH, keyName, destinationAddress, amount)
  }
}

import Principal "mo:base/Principal";
import T "mo:base/Time";

import Env "../../config/Env";

module XTC {

  public type TxReceipt = { #Ok : Nat; #Err : TxError };

  public type TxRecord = {
    index : Nat;
    from : Principal;
    to : Principal;
    amount : Nat;
    timestamp : T.Time
  };

  public type TxError = {
    #InsufficientAllowance;
    #InsufficientBalance;
    #ErrorOperationStyle;
    #Unauthorized;
    #LedgerTrap;
    #ErrorTo;
    #Other;
    #BlockUsed;
    #AmountTooSmall;
    #FetchRateFailed;
    #NotifyDfxFailed;
    #UnexpectedCyclesResponse;
    #InsufficientXTCFee
  };

  public let Actor = actor (Env.xtcCanisterId) : actor {
    balanceOf : (Principal) -> async Nat;
    getTransaction : (Nat) -> async TxRecord;
    transferErc20 : (Principal, Nat) -> async TxReceipt
  };

}

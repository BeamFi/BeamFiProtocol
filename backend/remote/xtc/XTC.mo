import Principal "mo:base/Principal";
import R "mo:base/Result";
import T "mo:base/Time";

import Env "../../config/Env";

module XTC {

  type Result<Ok, Err> = R.Result<Ok, Err>;

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
    #AmountTooSmall
  };

  public type TxReceipt = Result<Nat, TxError>;

  public let Actor = actor (Env.xtcCanisterId) : actor {
    balanceOf : (Principal) -> async Nat;
    getTransaction : (Nat) -> async TxRecord;
    transferErc20 : (Principal, Nat) -> async TxReceipt
  };

}

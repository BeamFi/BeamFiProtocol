import Principal "mo:base/Principal";

module Guard {

  let largeArgSize = 512;

  public func require(condition : Bool) : () {
    assert (condition)
  };

  public func isAnonymous(caller : Principal) : Bool {
    Principal.isAnonymous(caller)
  };

  public func isLargeArg(arg : Blob) : Bool {
    arg.size() > largeArgSize
  };

  public func withinSize(arg : Blob, size : Nat) : Bool {
    arg.size() <= size
  }

}

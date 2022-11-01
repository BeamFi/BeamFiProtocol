import T "mo:base/Time";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";

module DateUtil {

  type Time = T.Time;

  let OneMin: Int = 60000000000;
  let OneSec: Nat = 1000000000;

  public func addMinutes(date: Time, numMins: Int) : Time {
    date + numMins * OneMin;
  };

  public func isTimeBounded(timeA: Time, timeB: Time, numMins: Int) : Bool {
    Int.abs(timeA - timeB) <= numMins * OneMin;
  };

  public func numSecsBetween(timeA: Time, timeB: Time) : Nat {
    Int.abs(timeA - timeB) / OneSec;
  };
}
import H "mo:base/Hash";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Nat32 "mo:base/Nat32";
import Order "mo:base/Order";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import T "mo:base/Time";
import Trie "mo:base/Trie";

import JSON "../../http/JSON";

module BeamOutType {

  public type BeamOutId = Nat32;
  public type BeamOutStore = Trie.Trie<BeamOutId, BeamOutModel>;
  public type BeamOutStoreV2 = Trie.Trie<BeamOutId, BeamOutModelV2>;
  public type BeamOutStoreV3 = Trie.Trie<BeamOutId, BeamOutModelV3>;
  public type BeamOutMeetingId = Nat32;
  public type BeamOutMeetingString = Text;

  // e8s token format
  public type TokenAmount = Nat64;
  public type TokenType = { #icp };

  type Time = T.Time;
  type Hash = H.Hash;

  type KeyValueText = JSON.KeyValueText;
  type KeyValueList = JSON.KeyValueList;

  public type ErrorCode = {
    #invalid_recipient : Text;
    #invalid_id : Text;
    #duplicated_id : Text
  };

  type BeamOutType = {
    #payment;
    #meeting : BeamOutMeetingModel
  };

  type BeamOutModelV2 = {
    id : BeamOutId;
    createdAt : Time;
    updatedAt : Time;
    tokenType : TokenType;
    amount : TokenAmount;
    recipient : Principal;
    durationNumDays : Nat32;
    beamOutType : BeamOutType
  };

  public type BeamOutModelV3 = {
    id : BeamOutId;
    createdAt : Time;
    updatedAt : Time;
    tokenType : TokenType;
    amount : TokenAmount;
    recipient : Principal;
    durationNumDays : Nat32;
    beamOutType : BeamOutTypeV3
  };

  public type BeamOutTypeV3 = {
    #payment;
    #meeting : BeamOutMeetingModelV3
  };

  public type BeamOutMeetingModelV3 = {
    meetingId : BeamOutMeetingString;
    meetingPassword : Text
  };

  public type BeamOutModel = {
    id : BeamOutId;
    createdAt : Time;
    updatedAt : Time;
    tokenType : TokenType;
    amount : TokenAmount;
    recipient : Principal;
    durationNumDays : Nat32
  };

  type BeamOutMeetingModel = {
    meetingId : BeamOutMeetingId;
    meetingPassword : Text
  };

  public type BeamOutMetric = {
    totalURL : Nat;
    groupByDate : [BeamOutDateMetric]
  };

  public type BeamOutDateMetric = {
    numURL : Nat;
    dateString : Text
  };

  public func createBeamOut(
    id : BeamOutId,
    tokenType : TokenType,
    amount : TokenAmount,
    recipient : Principal,
    durationNumDays : Nat32
  ) : BeamOutModelV3 {
    let now = T.now();
    {
      id = id;
      createdAt = now;
      updatedAt = now;
      tokenType = tokenType;
      amount = amount;
      recipient = recipient;
      durationNumDays = durationNumDays;
      beamOutType = #payment
    }
  };

  public func createBeamOutMeeting(
    id : BeamOutId,
    tokenType : TokenType,
    amount : TokenAmount,
    recipient : Principal,
    durationNumDays : Nat32,
    meetingId : BeamOutMeetingString,
    meetingPassword : Text
  ) : BeamOutModelV3 {
    let now = T.now();
    {
      id = id;
      createdAt = now;
      updatedAt = now;
      tokenType = tokenType;
      amount = amount;
      recipient = recipient;
      durationNumDays = durationNumDays;
      beamOutType = #meeting({
        meetingId = meetingId;
        meetingPassword = meetingPassword
      })
    }
  };

  public func hash(beam : BeamOutModel) : Hash {
    Text.hash(Nat32.toText(beam.id))
  };

  public func beamIdHash(id : BeamOutId) : Hash {
    Text.hash(Nat32.toText(id))
  };

  public func beamIdEqual(id1 : BeamOutId, id2 : BeamOutId) : Bool {
    id1 == id2
  };

  public func textKey(x : Text) : Trie.Key<Text> { { key = x; hash = Text.hash(x) } };

  // desc order - the most recent will goto the top
  public func compareByCreatedAt(b1 : BeamOutModel, b2 : BeamOutModel) : Order.Order {
    if (b1.createdAt < b2.createdAt) {
      return #greater
    };

    if (b1.createdAt > b2.createdAt) {
      return #less
    };

    return #equal
  };

  // desc order - the most recent will goto the top
  public func compareByDateString(b1 : BeamOutDateMetric, b2 : BeamOutDateMetric) : Order.Order {
    if (b1.dateString < b2.dateString) {
      return #greater
    };

    if (b1.dateString > b2.dateString) {
      return #less
    };

    return #equal
  };

  public func equal(b1 : BeamOutModel, b2 : BeamOutModel) : Bool {
    b1.id == b2.id
  };

  public func idKey(id : BeamOutId) : Trie.Key<BeamOutId> { { key = id; hash = Text.hash(Nat32.toText(id)) } };

  public func dateMetricToJSON(m : BeamOutDateMetric) : KeyValueText {
    var kvList = JSON.addKeyNat("numURL", m.numURL, List.nil());
    kvList := JSON.addKeyText("date", m.dateString, kvList);

    let kvIter = Iter.fromList(kvList);
    "{" # Text.join(",", kvIter) # "}"
  };

  // {totalURL, groupByDate: [{ numURL,  date}]}
  public func toJSON(m : BeamOutMetric) : Text {
    var kvList = JSON.addKeyNat("totalURL", m.totalURL, List.nil());

    let datekvList : KeyValueList = List.map<BeamOutDateMetric, KeyValueText>(
      List.fromArray(m.groupByDate),
      func(m) : KeyValueText {
        dateMetricToJSON(m)
      }
    );
    let jsonText = JSON.createHeadlessArray("groupByDate", datekvList);

    let kvIter = Iter.fromList(kvList);
    "{" # Text.join(",", kvIter) # ", " # jsonText # "}"
  }

}

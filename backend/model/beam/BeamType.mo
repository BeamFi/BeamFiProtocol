import Debug "mo:base/Debug";
import Hash "mo:base/Hash";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Nat32 "mo:base/Nat32";
import Option "mo:base/Option";
import Order "mo:base/Order";
import Text "mo:base/Text";
import T "mo:base/Time";
import Trie "mo:base/Trie";

import JSON "../../http/JSON";
import EscrowType "../escrow/EscrowType";

module BeamType {

  public type BeamId = Nat32;
  // Period in secs
  public type Period = Nat32;

  type Time = T.Time;
  type EscrowId = EscrowType.EscrowId;
  type Hash = Hash.Hash;

  type KeyValueText = JSON.KeyValueText;
  type KeyValueList = JSON.KeyValueList;

  public type BeamStore = Trie.Trie<BeamId, BeamModel>;
  public type BeamStoreV2 = Trie.Trie<BeamId, BeamModelV2>;
  public type EscrowBeamStore = Trie.Trie<EscrowId, BeamId>;
  public type BeamRelationStore = Trie.Trie<BeamRelationObjId, BeamId>;

  public type BeamStatus = { #created; #active; #paused; #completed };
  public type BeamSortBy = { #lastProcessedDate };

  public type ErrorCode = { #invalid_beam : Text; #beam_notfound : Text; #permission_denied : Text };

  public type BeamRelationObjId = Text;

  public type BeamType = {
    #payment;
    #relation : BeamRelationModel
  };

  public type BeamRelationModel = {
    objId : BeamRelationObjId
  };

  public type BeamModel = {
    id : BeamId;
    escrowId : EscrowId;
    startDate : Time;
    scheduledEndDate : Time;
    actualEndDate : ?Time;
    rate : Period;
    status : BeamStatus;
    lastProcessedDate : Time;
    createdAt : Time;
    updatedAt : Time
  };

  public type BeamModelV2 = {
    id : BeamId;
    escrowId : EscrowId;
    startDate : Time;
    scheduledEndDate : Time;
    actualEndDate : ?Time;
    rate : Period;
    status : BeamStatus;
    lastProcessedDate : Time;
    createdAt : Time;
    updatedAt : Time;
    beamType : BeamType
  };

  public type BeamReadModel = {
    id : BeamId;
    escrowId : EscrowId;
    startDate : Time;
    scheduledEndDate : Time;
    status : BeamStatus;
    createdAt : Time;
    beamType : BeamType
  };

  // {totalNumBeam, totalICPVolume, groupByDate: [{numBeam, icpVolume, date}]}
  public type BeamMetric = {
    totalNumBeam : Nat;
    groupByDate : [BeamDateMetric]
  };

  public type BeamDateMetric = {
    numBeam : Nat;
    dateString : Text
  };

  public func createBeam(id : BeamId, escrowId : EscrowId, scheduledEndDate : Time, rate : Period) : BeamModelV2 {
    let now = T.now();
    {
      id = id;
      escrowId = escrowId;
      startDate = now;
      scheduledEndDate = scheduledEndDate;
      actualEndDate = null;
      rate = rate;
      status = #active;
      lastProcessedDate = now;
      createdAt = now;
      updatedAt = now;
      beamType = #payment
    }
  };

  public func createRelationBeam(id : BeamId, escrowId : EscrowId, scheduledEndDate : Time, rate : Period, objId : BeamRelationObjId) : BeamModelV2 {
    let now = T.now();
    {
      id = id;
      escrowId = escrowId;
      startDate = now;
      scheduledEndDate = scheduledEndDate;
      actualEndDate = null;
      rate = rate;
      status = #created;
      lastProcessedDate = now;
      createdAt = now;
      updatedAt = now;
      beamType = #relation({
        objId = objId
      })
    }
  };

  public func updateBeam(beam : BeamModelV2, processedDate : Time, status : BeamStatus) : BeamModelV2 {
    let now = T.now();
    let orgDuration = beam.scheduledEndDate - beam.startDate;

    let actualEndDate = do {
      // set actualEndDate to now if the new status is #completed and different from original status
      if (status == #completed and status != beam.status) {
        ?now
      } else {
        beam.actualEndDate
      }
    };
    let newStartDate = do {
      // set startDate to now if the new status is #active and original status is #created
      if (status == #active and beam.status == #created) {
        now
      } else {
        beam.startDate
      }
    };
    let newScheduledEndDate = do {
      // update scheduledEndDate based on startDate and duration if the new status is #active and original status is #created
      if (status == #active and beam.status == #created) {
        newStartDate + orgDuration
      } else {
        beam.scheduledEndDate
      }
    };

    {
      id = beam.id;
      escrowId = beam.escrowId;
      startDate = newStartDate;
      scheduledEndDate = newScheduledEndDate;
      actualEndDate = actualEndDate;
      rate = beam.rate;
      status = status;
      lastProcessedDate = processedDate;
      createdAt = beam.createdAt;
      updatedAt = now;
      beamType = beam.beamType
    }
  };

  public func undoBeam(currentBeam : BeamModelV2, updatedBeam : BeamModelV2, orgBeam : BeamModelV2) : BeamModelV2 {
    let now = T.now();

    // undo status and actualEndDate if currentBeam.status != original status and the latest update is from my call
    let status = do {
      if (currentBeam.status != orgBeam.status and currentBeam.updatedAt == updatedBeam.updatedAt) {
        orgBeam.status
      } else {
        currentBeam.status
      }
    };

    // undo actualEndDate if currentBeam.actualEndDate != original actualEndDate and the latest update is from my call
    let actualEndDate = do {
      if (currentBeam.actualEndDate != orgBeam.actualEndDate and currentBeam.updatedAt == updatedBeam.updatedAt) {
        orgBeam.actualEndDate
      } else {
        currentBeam.actualEndDate
      }
    };

    // undo actualStartDate if currentBeam.actualStartDate != original actualStartDate and the latest update is from my call
    let startDate = do {
      if (currentBeam.startDate != orgBeam.startDate and currentBeam.updatedAt == updatedBeam.updatedAt) {
        orgBeam.startDate
      } else {
        currentBeam.startDate
      }
    };

    // undo scheduledEndDate if currentBeam.scheduledEndDate != original scheduledEndDate and the latest update is from my call
    let scheduledEndDate = do {
      if (currentBeam.scheduledEndDate != orgBeam.scheduledEndDate and currentBeam.updatedAt == updatedBeam.updatedAt) {
        orgBeam.scheduledEndDate
      } else {
        currentBeam.scheduledEndDate
      }
    };

    {
      id = currentBeam.id;
      escrowId = currentBeam.escrowId;
      startDate = startDate;
      scheduledEndDate = scheduledEndDate;
      actualEndDate = actualEndDate;
      rate = currentBeam.rate;
      status = status;
      lastProcessedDate = currentBeam.lastProcessedDate;
      createdAt = currentBeam.createdAt;
      updatedAt = now;
      beamType = currentBeam.beamType
    }
  };

  public func validateBeam(beam : BeamModelV2) : Bool {
    // if actualEndDate is set, actualEndDate must be > startDate
    if (Option.isSome(beam.actualEndDate)) {
      switch (beam.actualEndDate) {
        case null ();
        case (?myActualEndDate) {
          if (myActualEndDate <= beam.startDate) {
            return false
          }
        }
      }
    };

    return beam.startDate < beam.scheduledEndDate
  };

  public func errorMesg(errorCode : ErrorCode) : Text {
    switch errorCode {
      case (#invalid_beam content) content;
      case (#beam_notfound content) content;
      case (#permission_denied content) content
    }
  };

  public func printBeamArray(beamArray : [BeamModelV2]) {
    for (beam in beamArray.vals()) {
      Debug.print(debug_show (beam))
    }
  };

  public func hash(beam : BeamModelV2) : Hash {
    Text.hash(Nat32.toText(beam.id))
  };

  public func beamIdHash(id : BeamId) : Hash {
    Text.hash(Nat32.toText(id))
  };

  public func beamIdEqual(id1 : BeamId, id2 : BeamId) : Bool {
    id1 == id2
  };

  // asc order - the most recent will goto the bottom
  public func compareByLastProcessedDate(b1 : BeamModelV2, b2 : BeamModelV2) : Order.Order {
    if (b1.lastProcessedDate > b2.lastProcessedDate) {
      return #less
    };

    if (b1.lastProcessedDate < b2.lastProcessedDate) {
      return #greater
    };

    return #equal
  };

  // asc order - the most recent will goto the bottom
  public func compareByStartDate(b1 : BeamModelV2, b2 : BeamModelV2) : Order.Order {
    if (b1.startDate > b2.startDate) {
      return #less
    };

    if (b1.startDate < b2.startDate) {
      return #greater
    };

    return #equal
  };

  // desc order - the most recent will goto the top
  public func compareByDateString(b1 : BeamDateMetric, b2 : BeamDateMetric) : Order.Order {
    if (b1.dateString < b2.dateString) {
      return #greater
    };

    if (b1.dateString > b2.dateString) {
      return #less
    };

    return #equal
  };

  public func equal(b1 : BeamModelV2, b2 : BeamModelV2) : Bool {
    b1.id == b2.id
  };

  public func idKey(id : BeamId) : Trie.Key<BeamId> { { key = id; hash = Text.hash(Nat32.toText(id)) } };
  public func relIdKey(id : BeamRelationObjId) : Trie.Key<BeamRelationObjId> { { key = id; hash = Text.hash(id) } };

  public func textKey(x : Text) : Trie.Key<Text> { { key = x; hash = Text.hash(x) } };

  public func dateMetricToJSON(m : BeamDateMetric) : KeyValueText {
    var kvList = JSON.addKeyNat("numBeam", m.numBeam, List.nil());
    kvList := JSON.addKeyText("date", m.dateString, kvList);

    let kvIter = Iter.fromList(kvList);
    "{" # Text.join(",", kvIter) # "}"
  };

  // {totalNumBeam, groupByDate: [{numBeam, date}]}
  public func toJSON(m : BeamMetric) : Text {
    var kvList = JSON.addKeyNat("totalNumBeam", m.totalNumBeam, List.nil());

    let datekvList : KeyValueList = List.map<BeamDateMetric, KeyValueText>(
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

import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Cycles "mo:base/ExperimentalCycles";
import List "mo:base/List";
import Nat32 "mo:base/Nat32";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import R "mo:base/Result";
import T "mo:base/Time";
import Trie "mo:base/Trie";

import Env "../config/Env";
import Http "../http/Http";
import JSON "../http/JSON";
import BeamOutStoreHelper "../model/beam/BeamOutStoreHelper";
import BeamOutType "../model/beam/BeamOutType";
import Guard "../utils/Guard";
import NumberUtil "../utils/NumberUtil";

actor BeamOut {

  type BeamOutId = BeamOutType.BeamOutId;
  type TokenType = BeamOutType.TokenType;
  type TokenAmount = BeamOutType.TokenAmount;

  type BeamOutModelV3 = BeamOutType.BeamOutModelV3;
  type BeamOutStore = BeamOutType.BeamOutStore;
  type BeamOutStoreV2 = BeamOutType.BeamOutStoreV2;
  type BeamOutStoreV3 = BeamOutType.BeamOutStoreV3;

  type BeamOutMetric = BeamOutType.BeamOutMetric;
  type BeamOutDateMetric = BeamOutType.BeamOutDateMetric;
  type BeamOutMeetingString = BeamOutType.BeamOutMeetingString;

  type HttpRequest = Http.HttpRequest;
  type HttpResponse = Http.HttpResponse;

  type KeyValueText = JSON.KeyValueText;

  type ErrorCode = BeamOutType.ErrorCode;

  type Time = T.Time;
  type Result<Ok, Err> = R.Result<Ok, Err>;

  let require = Guard.require;

  let version : Nat32 = 1;

  stable var beamOutStore : BeamOutStore = Trie.empty();
  stable var beamOutStoreV3 : BeamOutStoreV3 = Trie.empty();

  public func createBeamOut(amount : TokenAmount, tokenType : TokenType, recipient : Principal, durationNumDays : Nat32) : async Result<BeamOutId, ErrorCode> {
    // Generate 9 digits random id
    let opId = await NumberUtil.generateRandomDigits(9);
    let id = switch opId {
      case null return #err(#invalid_id("Problem encountered when generating random id"));
      case (?myId) myId
    };

    // Create BeamOutModel
    let beamOut = BeamOutType.createBeamOut(id, tokenType, amount, recipient, durationNumDays);

    // Check if there is duplicate id
    let found = BeamOutStoreHelper.findBeamOutById(beamOutStoreV3, id);
    if (not Option.isNull(found)) {
      return #err(#duplicated_id("Duplicated id is found"))
    };

    // Persist BeamOutModel to store
    beamOutStoreV3 := BeamOutStoreHelper.updateBeamOutStore(beamOutStoreV3, beamOut);

    #ok(beamOut.id)
  };

  // Create BeamOutModel with meetingId and meetingPassword
  public func createBeamOutMeeting(amount : TokenAmount, tokenType : TokenType, recipient : Principal, durationNumDays : Nat32, meetingId : BeamOutMeetingString, meetingPassword : Text) : async Result<BeamOutId, ErrorCode> {
    // Generate 9 digits random id
    let opId = await NumberUtil.generateRandomDigits(9);
    let id = switch opId {
      case null return #err(#invalid_id("Problem encountered when generating random id"));
      case (?myId) myId
    };

    // Create BeamOutModel
    let beamOut = BeamOutType.createBeamOutMeeting(id, tokenType, amount, recipient, durationNumDays, meetingId, meetingPassword);

    // Check if there is duplicate id
    let found = BeamOutStoreHelper.findBeamOutById(beamOutStoreV3, id);
    if (not Option.isNull(found)) {
      return #err(#duplicated_id("Duplicated id is found"))
    };

    // Persist BeamOutModel to store
    beamOutStoreV3 := BeamOutStoreHelper.updateBeamOutStore(beamOutStoreV3, beamOut);

    #ok(beamOut.id)
  };

  public query func loadBeamOutById(id : BeamOutId) : async Result<BeamOutModelV3, ErrorCode> {
    let beamOut = BeamOutStoreHelper.findBeamOutById(beamOutStoreV3, id);
    switch beamOut {
      case null return #err(#invalid_id("Beam out id not found"));
      case (?myBeamOut) return #ok(myBeamOut)
    }
  };

  // Private func - trap if caller is not manager
  func requireManager(caller : Principal) : () {
    require(Env.getManager() == caller)
  };

  // Public func - @return actor cycles balance
  public query ({ caller }) func getActorBalance() : async Nat {
    requireManager(caller);
    return Cycles.balance()
  };

  // Metrics - reportMetric in HTTP request: {totalURL, groupByDate: [{ numURL,  date}]}
  func reportMetric() : BeamOutMetric {
    let totalURL : Nat = BeamOutStoreHelper.queryTotalBeamOut(beamOutStoreV3);
    let groupByDate : [BeamOutDateMetric] = BeamOutStoreHelper.queryBeamOutDate(beamOutStoreV3);

    {
      totalURL;
      groupByDate
    }
  };

  public query func http_request(req : HttpRequest) : async HttpResponse {
    let parsedURL = Http.parseURL(req.url);

    switch (parsedURL) {
      case (#err(_)) Http.BadRequest();
      case (#ok(endPoint, queryParams)) {
        if (not Http.checkKey(queryParams, "clientKey", Env.clientKey)) {
          return Http.BadRequest()
        };

        switch (endPoint) {
          case "/metric" {
            let metric = reportMetric();
            let jsonText = BeamOutType.toJSON(metric);
            Http.JsonContent(jsonText, false)
          };
          case "/health" {
            let jsonText = JSON.createArray("result", List.nil<KeyValueText>());
            Http.JsonContent(jsonText, false)
          };
          case _ Http.BadRequest()
        }
      }
    }
  };

  system func postupgrade() {
    // only upgrade if beamOutStoreV3 is empty
    if (not Trie.isEmpty(beamOutStoreV3)) {
      Debug.print("Skip migrating beamOutStore to beamOutStoreV3 as beamOutStoreV3 is not empty");
      return
    };

    beamOutStoreV3 := BeamOutStoreHelper.upgradeBeamOutStore(beamOutStore)
  };

}

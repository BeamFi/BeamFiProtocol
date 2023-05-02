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
  type BeamOutModelV4 = BeamOutType.BeamOutModelV4;

  type TokenType = BeamOutType.TokenType;
  type TokenAmount = BeamOutType.TokenAmount;

  type BeamOutStore = BeamOutType.BeamOutStore;
  type BeamOutStoreV4 = BeamOutType.BeamOutStoreV4;

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

  stable var beamOutStoreV4 : BeamOutStoreV4 = Trie.empty();

  public func createBeamOut(amount : TokenAmount, tokenType : TokenType, recipient : Principal, durationNumMins : Nat32) : async Result<BeamOutId, ErrorCode> {
    // Generate 9 digits random id
    let opId = await NumberUtil.generateRandomDigits(9);
    let id = switch opId {
      case null return #err(#invalid_id("Problem encountered when generating random id"));
      case (?myId) myId
    };

    // Create BeamOutModel
    let beamOut = BeamOutType.createBeamOut(id, tokenType, amount, recipient, durationNumMins);

    // Check if there is duplicate id
    let found = BeamOutStoreHelper.findBeamOutById(beamOutStoreV4, id);
    if (not Option.isNull(found)) {
      return #err(#duplicated_id("Duplicated id is found"))
    };

    // Persist BeamOutModel to store
    beamOutStoreV4 := BeamOutStoreHelper.updateBeamOutStore(beamOutStoreV4, beamOut);

    #ok(beamOut.id)
  };

  // Create BeamOutModel with meetingId and meetingPassword
  public func createBeamOutMeeting(amount : TokenAmount, tokenType : TokenType, recipient : Principal, durationNumMins : Nat32, meetingId : BeamOutMeetingString, meetingPassword : Text) : async Result<BeamOutId, ErrorCode> {
    // Generate 9 digits random id
    let opId = await NumberUtil.generateRandomDigits(9);
    let id = switch opId {
      case null return #err(#invalid_id("Problem encountered when generating random id"));
      case (?myId) myId
    };

    // Create BeamOutModel
    let beamOut = BeamOutType.createBeamOutMeeting(id, tokenType, amount, recipient, durationNumMins, meetingId, meetingPassword);

    // Check if there is duplicate id
    let found = BeamOutStoreHelper.findBeamOutById(beamOutStoreV4, id);
    if (not Option.isNull(found)) {
      return #err(#duplicated_id("Duplicated id is found"))
    };

    // Persist BeamOutModel to store
    beamOutStoreV4 := BeamOutStoreHelper.updateBeamOutStore(beamOutStoreV4, beamOut);

    #ok(beamOut.id)
  };

  public query func loadBeamOutById(id : BeamOutId) : async Result<BeamOutModelV4, ErrorCode> {
    let beamOut = BeamOutStoreHelper.findBeamOutById(beamOutStoreV4, id);
    switch beamOut {
      case null return #err(#invalid_id("Beam out id not found"));
      case (?myBeamOut) return #ok(myBeamOut)
    }
  };

  // Public func - @return actor cycles balance
  public query ({ caller }) func getActorBalance() : async Nat {
    return Cycles.balance()
  };

  // Metrics - reportMetric in HTTP request: {totalURL, groupByDate: [{ numURL,  date}]}
  func reportMetric() : BeamOutMetric {
    let totalURL : Nat = BeamOutStoreHelper.queryTotalBeamOut(beamOutStoreV4);
    let groupByDate : [BeamOutDateMetric] = BeamOutStoreHelper.queryBeamOutDate(beamOutStoreV4);

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

}

import BeamEscrow "canister:beamescrow";

import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Cycles "mo:base/ExperimentalCycles";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Int64 "mo:base/Int64";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";
import R "mo:base/Result";
import Text "mo:base/Text";
import T "mo:base/Time";
import Trie "mo:base/Trie";

import Env "../config/Env";
import Http "../http/Http";
import JSON "../http/JSON";
import BeamRelationStoreHelper "../model/beam/BeamRelationStoreHelper";
import BeamStoreHelper "../model/beam/BeamStoreHelper";
import BeamType "../model/beam/BeamType";
import EscrowType "../model/escrow/EscrowType";
import DateUtil "../utils/DateUtil";
import Guard "../utils/Guard";
import Op "../utils/Operation";
import TextUtil "../utils/TextUtil";
import ZoomUtil "../utils/ZoomUtil";

actor Beam {

  type BeamModel = BeamType.BeamModel;
  type BeamModelV2 = BeamType.BeamModelV2;
  type BeamReadModel = BeamType.BeamReadModel;
  type BeamId = BeamType.BeamId;
  type Period = BeamType.Period;
  type ErrorCode = BeamType.ErrorCode;
  type BeamStatus = BeamType.BeamStatus;
  type BeamMetric = BeamType.BeamMetric;
  type BeamDateMetric = BeamType.BeamDateMetric;
  type BeamRelationObjId = BeamType.BeamRelationObjId;

  type EscrowId = EscrowType.EscrowId;
  type Allocation = EscrowType.Allocation;

  type HttpRequest = Http.HttpRequest;
  type HttpResponse = Http.HttpResponse;
  type QueryParam = Http.QueryParam;

  type KeyValueText = JSON.KeyValueText;

  type Time = T.Time;
  type Result<Ok, Err> = R.Result<Ok, Err>;

  stable var nextBeamId : BeamId = 0;
  stable var version : Nat32 = 0;

  stable var beamStore : Trie.Trie<BeamId, BeamModel> = Trie.empty();
  stable var beamStoreV2 : Trie.Trie<BeamId, BeamModelV2> = Trie.empty();
  stable var escrowBeamStore : Trie.Trie<EscrowId, BeamId> = Trie.empty();
  stable var beamRelationStore : Trie.Trie<BeamRelationObjId, BeamId> = Trie.empty();

  let topNBeams : Nat = 5;
  let require = Guard.require;

  // Persistent heartbeat count
  var hbCount = 0;
  // 3 beats ~ 6-9 secs
  let hbBeamPaymentEveryN = 3;

  // Public func - Create new Beam for the EscrowContract escrowId and start beaming
  // @return beamId if #ok, errorCode if #err
  public shared ({ caller }) func createBeam(escrowId : EscrowId, scheduledEndDate : Time, rate : Period) : async Result<BeamId, ErrorCode> {
    // allow only beamescrow canister
    requireBeamEscrowCanisters(caller);

    // --- Atomicity starts ---
    let beamId = nextBeamId;
    nextBeamId += 1;

    // Create new Beam
    let beam = BeamType.createBeam(beamId, escrowId, scheduledEndDate, rate);

    // Add to beamStore and escrowBeamStore
    beamStoreV2 := BeamStoreHelper.updateBeamStore(beamStoreV2, beam);
    escrowBeamStore := BeamStoreHelper.updateEscrowBeamStore(escrowBeamStore, escrowId, beamId);

    // --- Actor state changes commited ---
    #ok(beamId)
  };

  // Create new beam with relation to external object id and paused beginning status. Use cases: Zoom Meeting
  public shared ({ caller }) func createRelationBeam(escrowId : EscrowId, scheduledEndDate : Time, rate : Period, objId : BeamRelationObjId) : async Result<BeamId, ErrorCode> {
    // allow only beamescrow canister
    requireBeamEscrowCanisters(caller);

    // --- Atomicity starts ---
    let beamId = nextBeamId;
    nextBeamId += 1;

    // Create new Beam
    let beam = BeamType.createRelationBeam(beamId, escrowId, scheduledEndDate, rate, objId);

    // Add to beamStore, escrowBeamStore and beamEscrowRelationStore
    beamStoreV2 := BeamStoreHelper.updateBeamStore(beamStoreV2, beam);
    escrowBeamStore := BeamStoreHelper.updateEscrowBeamStore(escrowBeamStore, escrowId, beamId);
    beamRelationStore := BeamRelationStoreHelper.updateBeamRelationStore(beamRelationStore, beamId, objId);

    // --- Actor state changes commited ---
    #ok(beamId)
  };

  // Stop the beam from streaming by setting the status to #paused
  // Callable by Beam sender only
  public shared ({ caller }) func stopBeam(escrowId : EscrowId) : async Result<BeamStatus, ErrorCode> {
    await actionOnBeam(escrowId, #paused, caller)
  };

  // Restart the beam by setting status to #active
  // Callable by Beam sender only
  public shared ({ caller }) func restartBeam(escrowId : EscrowId) : async Result<BeamStatus, ErrorCode> {
    await actionOnBeam(escrowId, #active, caller)
  };

  func actionOnBeam(escrowId : EscrowId, status : BeamStatus, caller : Principal) : async Result<BeamStatus, ErrorCode> {
    // Assert caller to be Beam sender
    let result = await BeamEscrow.queryMyBeamEscrowBySender(escrowId, caller);
    let escrow = switch result {
      case (#ok myContract) myContract;
      case (#err content) return #err(#permission_denied(EscrowType.errorMesg(content)))
    };

    if (escrow.buyerPrincipal != caller) {
      return #err(#permission_denied("Only beam sender can action on the beam"))
    };

    // fetch and update Beam.status to the status
    let opBeam = BeamStoreHelper.findBeamByEscrowId(beamStoreV2, escrowBeamStore, escrowId);
    let beam = switch opBeam {
      case null {
        return #err(#beam_notfound("Cannot find the beam."))
      };
      case (?myBeam) myBeam
    };

    let now = T.now();
    let updatedBeam = BeamType.updateBeam(beam, now, status);

    // persist beam
    beamStoreV2 := BeamStoreHelper.updateBeamStore(beamStoreV2, updatedBeam);

    #ok(updatedBeam.status)
  };

  func privateActionOnBeam(beamId : BeamId, status : BeamStatus) : () {
    // fetch and update Beam.status to the status
    let opBeam = BeamStoreHelper.findBeamById(beamStoreV2, beamId);
    let beam = switch opBeam {
      case null return;
      case (?myBeam) myBeam
    };

    let now = T.now();
    let updatedBeam = BeamType.updateBeam(beam, now, status);

    // persist beam
    beamStoreV2 := BeamStoreHelper.updateBeamStore(beamStoreV2, updatedBeam)
  };

  // Private func - Find and process active BeamModels, called by heartbeat
  func processActiveBeams() : async () {
    let beamArray = Trie.toArray<BeamId, BeamModelV2, BeamModelV2>(
      beamStoreV2,
      func(key, value) : BeamModelV2 {
        value
      }
    );

    // Filter active beams only
    let activeBeamArray = BeamStoreHelper.filterActiveBeams(beamArray);

    // Find top 5 active beams ordered by lastProcessedDate
    let topNArray = BeamStoreHelper.orderBy(activeBeamArray, #lastProcessedDate, topNBeams);

    // Iterate beamArray with beamPayment
    for (beam in topNArray.vals()) {
      await beamPayment(beam)
    }
  };

  // Private func - Beam (stream) payment to creator over time
  // Follow Checks-Effects-Interactions-Rollback pattern
  func beamPayment(beam : BeamModelV2) : async () {
    // ----- Checks
    // only do beaming (streaming) if numSec(now - lastProcessedDate) >= rate
    let now = T.now();

    if (DateUtil.numSecsBetween(now, beam.lastProcessedDate) < Nat32.toNat(beam.rate)) {
      return
    };

    // ----- Effects

    // --- Atomicity starts ---
    // calculate the progress 0-1.0 of beam using min(1, (now - startDate) / scheduledEndDate)
    // use the progress to update creator claimable allocation
    var progress : Float = Float.fromInt(now - beam.startDate) / Float.fromInt(beam.scheduledEndDate - beam.startDate);
    progress := Float.min(1.0, progress);

    // Allocation is in Nat64 with e6s base e.g 10 = 10/1000000
    let allocationBaseFloat = Float.fromInt64(Int64.fromNat64(EscrowType.allocationBase));
    let allocationInt : Int = Int64.toInt(Float.toInt64(progress * allocationBaseFloat));

    let creatorAllocation : Allocation = Nat64.fromNat(Int.abs(allocationInt));
    assert (creatorAllocation <= EscrowType.allocationBase and creatorAllocation >= 0);

    let escrowAllocation = EscrowType.allocationBase - creatorAllocation;

    // update Beam to BeamStore
    let status : BeamStatus = do {
      if (creatorAllocation == EscrowType.allocationBase and beam.status == #active) {
        #completed
      } else {
        beam.status
      }
    };

    let updatedBeam = BeamType.updateBeam(beam, T.now(), status);
    if (not BeamType.validateBeam(updatedBeam)) {
      Debug.print("Invalid beam data for beamPayment");
      return
    };

    beamStoreV2 := BeamStoreHelper.updateBeamStore(beamStoreV2, updatedBeam);
    // --- Actor state changes commited ---

    // ----- Interactions
    let result = await BeamEscrow.updateEscrowAllocation(beam.escrowId, escrowAllocation, creatorAllocation, 0);
    // Security - note another party can call beamPayment here (incl internally) while updateEscrowAllocation is processing

    // ----- Rollback or Success
    switch result {
      case (#ok content)();
      case (#err content) {
        // Rollback if updateEscrowAllocation fails
        Debug.print(debug_show content);

        // --- Atomicity starts ---

        // load the beam again due to reentrancy, the beam above may have changed after updateEscrowAllocation
        let opBeam = BeamStoreHelper.findBeamById(beamStoreV2, updatedBeam.id);
        let currentBeam = switch opBeam {
          case null {
            Debug.print("BeamModel not found");
            return ()
          };
          case (?myBeam) myBeam
        };

        let rollbackedBeam = BeamType.undoBeam(currentBeam, updatedBeam, beam);
        beamStoreV2 := BeamStoreHelper.updateBeamStore(beamStoreV2, rollbackedBeam);
        // --- Actor state changes commited ---
      }
    }
  };

  public query func queryBeamByEscrowIds(idArray : [EscrowId]) : async [BeamReadModel] {
    return BeamStoreHelper.loadBeamReadModelByEscrowIds(beamStoreV2, escrowBeamStore, idArray)
  };

  // Trap if the caller is not BeamEscrow canister
  func requireBeamEscrowCanisters(caller : Principal) : () {
    if (caller == Principal.fromText(Env.beamEscrowCanisterId)) {
      return
    };

    assert (false)
  };

  // Triggered during heartbeat, check if should call processActiveBeams
  system func heartbeat() : async () {
    if (hbCount % hbBeamPaymentEveryN == 0) {
      await processActiveBeams()
    };

    hbCount += 1
  };

  // Public func - simple health check
  // @return true
  public query func healthCheck() : async Bool {
    true
  };

  // Public func - @return canister version
  public query func canisterVersion() : async Nat32 {
    version
  };

  // Public func - @return actor cycles balance
  public query ({ caller }) func getActorBalance() : async Nat {
    requireManager(caller);
    return Cycles.balance()
  };

  // Private func - trap if caller is not manager
  func requireManager(caller : Principal) : () {
    require(Env.getManager() == caller)
  };

  // Public func - @return manager principal
  public query func getManager() : async Principal {
    Env.getManager()
  };

  // Public func - @return canister memory info
  public query func getCanisterMemoryInfo() : async Op.CanisterMemoryInfo {
    return Op.getCanisterMemoryInfo()
  };

  type MesgType = {
    // approved canister update - non-anonymous, arg sie <= 256 or 128
    #createBeam : () -> (EscrowId, Time, Period);
    #createRelationBeam : () -> (EscrowId, Time, Period, BeamRelationObjId);
    #stopBeam : () -> EscrowId;
    #restartBeam : () -> EscrowId;

    // admin read - won't invoke inspect
    #getActorBalance : () -> ();

    // public read - won't invoke inspect
    #queryBeamByEscrowIds : () -> [EscrowId];
    #canisterVersion : () -> ();
    #getCanisterMemoryInfo : () -> ();
    #getManager : () -> ();
    #healthCheck : () -> ();
    #http_request : () -> HttpRequest
  };

  system func inspect({ arg : Blob; caller : Principal; msg : MesgType }) : Bool {
    switch msg {
      case (#createBeam _) not Guard.isAnonymous(caller) and Guard.withinSize(arg, 256);
      case (#createRelationBeam _) not Guard.isAnonymous(caller) and Guard.withinSize(arg, 256);
      case (#stopBeam _) not Guard.isAnonymous(caller) and Guard.withinSize(arg, 128);
      case (#restartBeam _) not Guard.isAnonymous(caller) and Guard.withinSize(arg, 128);
      case _ true
    }
  };

  // Metrics - reportMetric in HTTP request: {totalNumBeam, groupByDate: [{numBeam, date}]}
  func reportMetric() : BeamMetric {
    let totalNumBeam : Nat = BeamStoreHelper.queryTotalBeam(beamStoreV2);
    let groupByDate : [BeamDateMetric] = BeamStoreHelper.queryBeamDate(beamStoreV2);

    {
      totalNumBeam;
      groupByDate
    }
  };

  public query func http_request(req : HttpRequest) : async HttpResponse {
    let parsedURL = Http.parseURL(req.url);

    switch (parsedURL) {
      case (#err(_)) Http.BadRequest();
      case (#ok(endPoint, queryParams)) {
        switch (endPoint) {
          case "/metric" {
            processMetricRequest(queryParams)
          };
          case "/health" {
            processHealthRequest(queryParams)
          };
          case "/zoom" {
            Http.TextContentUpgrade("success", true)
          };
          case _ Http.BadRequest()
        }
      }
    }
  };

  public func http_request_update(req : HttpRequest) : async HttpResponse {
    let parsedURL = Http.parseURL(req.url);

    switch (parsedURL) {
      case (#err(_)) Http.BadRequest();
      case (#ok(endPoint, queryParams)) {
        switch (endPoint) {
          case "/zoom" {
            processZoomRequest(req)
          };
          case _ Http.BadRequest()
        }
      }
    }
  };

  func processMetricRequest(queryParams : [QueryParam]) : HttpResponse {
    if (not Http.checkKey(queryParams, "clientKey", Env.clientKey)) {
      return Http.BadRequest()
    };

    let metric = reportMetric();
    let jsonText = BeamType.toJSON(metric);
    Http.JsonContent(jsonText, false)
  };

  func processHealthRequest(queryParams : [QueryParam]) : HttpResponse {
    if (not Http.checkKey(queryParams, "clientKey", Env.clientKey)) {
      return Http.BadRequest()
    };

    let jsonText = JSON.createArray("result", List.nil<KeyValueText>());
    Http.JsonContent(jsonText, false)
  };

  func processZoomRequest(req : HttpRequest) : HttpResponse {
    let jsonStr = Text.decodeUtf8(req.body);

    switch (jsonStr) {
      case null Http.TextContent("Invalid string");
      case (?myStr) {
        var event = ZoomUtil.extractEvent(myStr, 2);
        if (event == null) {
          event := ZoomUtil.extractEvent(myStr, 0)
        };

        Debug.print(myStr);

        switch (event) {
          case null return Http.TextContent("No event found");
          case (?myEvent) {
            Debug.print("Zoom Event: " # myEvent);

            switch (myEvent) {
              case "endpoint.url_validation" {
                let jsonRes = ZoomUtil.processValidationRequest(myStr);
                return Http.JsonContent(jsonRes, false)
              };
              case ("meeting.started" or "meeting.ended") {
                // TODO - Enable signature verification
                // let isAuthentic = ZoomUtil.verifySignature(myStr, req.headers);
                // if (not isAuthentic) {
                //   return Http.BadRequestWith("Invalid signature")
                // };

                Debug.print("Zoom Meeting Event: " # myEvent);

                // start Beam
                let meetingIdOp = ZoomUtil.extractMeetingId(myStr);
                let meetingId = switch (meetingIdOp) {
                  case null {
                    Debug.print("Invalid meeting id");
                    return Http.BadRequestWith("Invalid meeting id")
                  };
                  case (?id) id
                };

                let beamIdOp = BeamRelationStoreHelper.findBeamIdByRelId(beamRelationStore, meetingId);
                let beamId = switch (beamIdOp) {
                  case null {
                    Debug.print("Beam Id not found");
                    return Http.BadRequestWith("Beam Id not found")
                  };
                  case (?id) id
                };

                let newStatus = switch (myEvent) {
                  case "meeting.started" #active;
                  case "meeting.ended" #paused;
                  case _ #active
                };

                privateActionOnBeam(beamId, newStatus);

                Debug.print("Event processed successfully");

                return Http.TextContent("Event processed successfully")
              };
              case _ {
                return Http.TextContent("No matching events found")
              }
            }
          }
        };

        Http.JsonContent("", false)
      }
    }
  };

  system func postupgrade() {
    // only upgrade if beamStoreV2 is empty
    if (not Trie.isEmpty(beamStoreV2)) {
      Debug.print("Skip migrating beamStore to beamStoreV2 as beamStoreV2 is not empty");
      return
    };

    beamStoreV2 := BeamStoreHelper.upgradeBeamStore(beamStore)
  };

}

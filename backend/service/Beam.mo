import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";
import Float "mo:base/Float";
import Int64 "mo:base/Int64";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Trie "mo:base/Trie";
import R "mo:base/Result";
import T "mo:base/Time";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import List "mo:base/List";

import Op "../utils/Operation";
import Env "../config/Env";
import Guard "../utils/Guard";
import Http "../http/Http";
import JSON "../http/JSON";

import BeamType "../model/beam/BeamType";
import BeamStoreHelper "../model/beam/BeamStoreHelper";
import EscrowType "../model/escrow/EscrowType";
import DateUtil "../utils/DateUtil";

import BeamEscrow "canister:beamescrow";

actor Beam {

  type BeamModel = BeamType.BeamModel;
  type BeamReadModel = BeamType.BeamReadModel;
  type BeamId = BeamType.BeamId;
  type Period = BeamType.Period;
  type ErrorCode = BeamType.ErrorCode;
  type BeamStatus = BeamType.BeamStatus;
  type BeamMetric = BeamType.BeamMetric;
  type BeamDateMetric = BeamType.BeamDateMetric;

  type EscrowId = EscrowType.EscrowId;
  type Allocation = EscrowType.Allocation;

  type HttpRequest = Http.HttpRequest;
  type HttpResponse = Http.HttpResponse;

  type KeyValueText = JSON.KeyValueText;

  type Time = T.Time;
  type Result<Ok, Err> = R.Result<Ok, Err>;

  stable var nextBeamId : BeamId = 0;
  stable var version : Nat32 = 0;

  stable var beamStore : Trie.Trie<BeamId, BeamModel> = Trie.empty();
  stable var escrowBeamStore : Trie.Trie<EscrowId, BeamId> = Trie.empty();

  let topNBeams : Nat = 5;
  let require = Guard.require;

  // Persistent heartbeat count
  var hbCount = 0;
  // 3 beats ~ 6-9 secs
  let hbBeamPaymentEveryN = 3;

  // Public func - Create new Beam for the EscrowContract escrowId
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
    beamStore := BeamStoreHelper.updateBeamStore(beamStore, beam);
    escrowBeamStore := BeamStoreHelper.updateEscrowBeamStore(escrowBeamStore, escrowId, beamId);

    // --- Actor state changes commited ---
    #ok(beamId)
  };

  // Stop the beam from streaming
  // Callable by Beam sender only
  public shared ({ caller }) func stopBeam(escrowId : EscrowId) : async Result<BeamStatus, ErrorCode> {
    // TODO - assert caller to be Beam sender

    // fetch and update Beam.status to #paused
    let opBeam = BeamStoreHelper.findBeamByEscrowId(beamStore, escrowBeamStore, escrowId);
    let beam = switch opBeam {
      case null {
        return #err(#beam_notfound("Cannot find the beam."))
      };
      case (?myBeam) myBeam
    };

    let now = T.now();
    let updatedBeam = BeamType.updateBeam(beam, now, #paused);

    // persist beam
    beamStore := BeamStoreHelper.updateBeamStore(beamStore, updatedBeam);

    #ok(updatedBeam.status)
  };

  // Private func - Find and process active BeamModels, called by heartbeat
  func processActiveBeams() : async () {
    let beamArray = Trie.toArray<BeamId, BeamModel, BeamModel>(
      beamStore,
      func(key, value) : BeamModel {
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
  func beamPayment(beam : BeamModel) : async () {
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

    beamStore := BeamStoreHelper.updateBeamStore(beamStore, updatedBeam);
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
        let opBeam = BeamStoreHelper.findBeamById(beamStore, updatedBeam.id);
        let currentBeam = switch opBeam {
          case null {
            Debug.print("BeamModel not found");
            return ()
          };
          case (?myBeam) myBeam
        };

        let rollbackedBeam = BeamType.undoBeam(currentBeam, updatedBeam, beam);
        beamStore := BeamStoreHelper.updateBeamStore(beamStore, rollbackedBeam);
        // --- Actor state changes commited ---
      }
    }
  };

  public query func queryBeamByEscrowIds(idArray : [EscrowId]) : async [BeamReadModel] {
    return BeamStoreHelper.loadBeamReadModelByEscrowIds(beamStore, escrowBeamStore, idArray)
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
    #stopBeam : () -> EscrowId;

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
      case (#stopBeam _) not Guard.isAnonymous(caller) and Guard.withinSize(arg, 128);
      case _ true
    }
  };

  // Metrics - reportMetric in HTTP request: {totalNumBeam, groupByDate: [{numBeam, date}]}
  func reportMetric() : BeamMetric {
    let totalNumBeam : Nat = BeamStoreHelper.queryTotalBeam(beamStore);
    let groupByDate : [BeamDateMetric] = BeamStoreHelper.queryBeamDate(beamStore);

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
        if (not Http.checkKey(queryParams, "clientKey", Env.clientKey)) {
          return Http.BadRequest()
        };

        switch (endPoint) {
          case "/metric" {
            let metric = reportMetric();
            let jsonText = BeamType.toJSON(metric);
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

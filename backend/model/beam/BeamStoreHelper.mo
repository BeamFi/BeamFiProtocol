import Array "mo:base/Array";
import Int "mo:base/Int";
import List "mo:base/List";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Trie "mo:base/Trie";

import DateTimeUtil "../../utils/DateTimeUtil";
import BeamType "../beam/BeamType";
import EscrowType "../escrow/EscrowType";

module BeamStoreHelper {

  type BeamId = BeamType.BeamId;
  type BeamModel = BeamType.BeamModel;
  type BeamModelV2 = BeamType.BeamModelV2;
  type BeamReadModel = BeamType.BeamReadModel;
  type BeamStore = BeamType.BeamStore;
  type BeamStoreV2 = BeamType.BeamStoreV2;
  type EscrowBeamStore = BeamType.EscrowBeamStore;
  type BeamSortBy = BeamType.BeamSortBy;
  type BeamDateMetric = BeamType.BeamDateMetric;

  type EscrowId = EscrowType.EscrowId;

  public func findBeamById(beamStore : BeamStoreV2, id : BeamId) : ?BeamModelV2 {
    return Trie.find<BeamId, BeamModelV2>(beamStore, BeamType.idKey(id), Nat32.equal)
  };

  public func loadBeamReadModelByEscrowIds(
    beamStore : BeamStoreV2,
    escrowBeamStore : EscrowBeamStore,
    idArray : [EscrowId]
  ) : [BeamReadModel] {
    Array.mapFilter<EscrowId, BeamReadModel>(
      idArray,
      func(id) : ?BeamReadModel {
        findBeamByEscrowId(beamStore, escrowBeamStore, id)
      }
    )
  };

  public func findBeamByEscrowId(beamStore : BeamStoreV2, escrowBeamStore : EscrowBeamStore, id : EscrowId) : ?BeamModelV2 {
    let opBeamId = Trie.find<EscrowId, BeamId>(escrowBeamStore, BeamType.idKey(id), Nat32.equal);

    switch opBeamId {
      case null return null;
      case (?myBeamId) return findBeamById(beamStore, myBeamId)
    }
  };

  public func updateBeamStore(beamStore : BeamStoreV2, beam : BeamModelV2) : BeamStoreV2 {
    let newStore = Trie.put(
      beamStore,
      BeamType.idKey(beam.id),
      Nat32.equal,
      beam
    ).0;
    return newStore
  };

  public func updateEscrowBeamStore(escrowBeamStore : EscrowBeamStore, escrowId : EscrowId, beamId : BeamId) : EscrowBeamStore {
    let newStore = Trie.put(
      escrowBeamStore,
      EscrowType.idKey(escrowId),
      Nat32.equal,
      beamId
    ).0;
    return newStore
  };

  public func filterActiveBeams(beamArray : [BeamModelV2]) : [BeamModelV2] {
    return Array.filter<BeamModelV2>(
      beamArray,
      func(beam) : Bool {
        beam.status == #active
      }
    )
  };

  public func orderBy(beamArray : [BeamModelV2], sortBy : BeamSortBy, topN : Nat) : [BeamModelV2] {
    let sortByFunc = do {
      switch (sortBy) {
        case (#lastProcessedDate) BeamType.compareByLastProcessedDate
      }
    };

    let sortedArray = Array.sort<BeamModelV2>(beamArray, sortByFunc);

    let sortedList = List.fromArray<BeamModelV2>(sortedArray);
    if (List.isNil(sortedList)) {
      return []
    };

    // Take topN
    let topList = List.take<BeamModelV2>(sortedList, topN);

    return List.toArray(topList)
  };

  public func queryTotalBeam(store : BeamStoreV2) : Nat {
    Trie.size(store)
  };

  func convertBeamTrieToArray(store : BeamStoreV2) : [BeamModelV2] {
    Trie.toArray<BeamId, BeamModelV2, BeamModelV2>(
      store,
      func(key, value) : BeamModelV2 {
        value
      }
    )
  };

  // {numBeam, date}
  public func queryBeamDate(store : BeamStoreV2) : [BeamDateMetric] {
    var dateNumBeamTrie : Trie.Trie<Text, BeamDateMetric> = Trie.empty();
    let beamArray = convertBeamTrieToArray(store);

    for (beam in beamArray.vals()) {
      let dateTime = DateTimeUtil.dateToCalendarDayText(beam.startDate);
      let numBeamMatched = Trie.get<Text, BeamDateMetric>(
        dateNumBeamTrie,
        BeamType.textKey(dateTime),
        Text.equal
      );
      let resultCount = switch numBeamMatched {
        case null 1;
        case (?metric) metric.numBeam + 1
      };

      let metric : BeamDateMetric = {
        dateString = dateTime;
        numBeam = resultCount
      };

      let result = Trie.put<Text, BeamDateMetric>(dateNumBeamTrie, BeamType.textKey(dateTime), Text.equal, metric);
      dateNumBeamTrie := result.0
    };

    let result = Trie.toArray<Text, BeamDateMetric, BeamDateMetric>(
      dateNumBeamTrie,
      func(key, value) : BeamDateMetric {
        value
      }
    );

    let sortByFunc = BeamType.compareByDateString;
    Array.sort<BeamDateMetric>(result, sortByFunc)
  };

  public func upgradeBeamStore(oldStore : BeamStore) : BeamStoreV2 {
    Trie.mapFilter<BeamId, BeamModel, BeamModelV2>(
      oldStore,
      func(beamId, old) : ?BeamModelV2 {
        ?{
          id = old.id;
          escrowId = old.escrowId;
          startDate = old.startDate;
          scheduledEndDate = old.scheduledEndDate;
          actualEndDate = old.actualEndDate;
          rate = old.rate;
          status = old.status;
          lastProcessedDate = old.lastProcessedDate;
          createdAt = old.createdAt;
          updatedAt = old.updatedAt;
          beamType = #payment
        }
      }
    )
  }

}

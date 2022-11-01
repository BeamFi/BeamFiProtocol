import Trie "mo:base/Trie";
import Nat32 "mo:base/Nat32";
import Array "mo:base/Array";
import List "mo:base/List";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Text "mo:base/Text";

import BeamType "../beam/BeamType";
import EscrowType "../escrow/EscrowType";

import DateTimeUtil "../../utils/DateTimeUtil";

module BeamStoreHelper {

  type BeamId = BeamType.BeamId;
  type BeamModel = BeamType.BeamModel;
  type BeamReadModel = BeamType.BeamReadModel;
  type BeamStore = BeamType.BeamStore;
  type EscrowBeamStore = BeamType.EscrowBeamStore;
  type BeamSortBy = BeamType.BeamSortBy;
  type BeamDateMetric = BeamType.BeamDateMetric;

  type EscrowId = EscrowType.EscrowId;

  public func findBeamById(beamStore : BeamStore, id : BeamId) : ?BeamModel {
    return Trie.find<BeamId, BeamModel>(beamStore, BeamType.idKey(id), Nat32.equal)
  };

  public func loadBeamReadModelByEscrowIds(
    beamStore : BeamStore,
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

  public func findBeamByEscrowId(beamStore : BeamStore, escrowBeamStore : EscrowBeamStore, id : EscrowId) : ?BeamModel {
    let opBeamId = Trie.find<EscrowId, BeamId>(escrowBeamStore, BeamType.idKey(id), Nat32.equal);

    switch opBeamId {
      case null return null;
      case (?myBeamId) return findBeamById(beamStore, myBeamId)
    }
  };

  public func updateBeamStore(beamStore : BeamStore, beam : BeamModel) : BeamStore {
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

  public func filterActiveBeams(beamArray : [BeamModel]) : [BeamModel] {
    return Array.filter<BeamModel>(
      beamArray,
      func(beam) : Bool {
        beam.status == #active
      }
    )
  };

  public func orderBy(beamArray : [BeamModel], sortBy : BeamSortBy, topN : Nat) : [BeamModel] {
    let sortByFunc = do {
      switch (sortBy) {
        case (#lastProcessedDate) BeamType.compareByLastProcessedDate
      }
    };

    let sortedArray = Array.sort<BeamModel>(beamArray, sortByFunc);

    let sortedList = List.fromArray<BeamModel>(sortedArray);
    if (List.isNil(sortedList)) {
      return []
    };

    // Take topN
    let topList = List.take<BeamModel>(sortedList, topN);

    return List.toArray(topList)
  };

  public func queryTotalBeam(store : BeamStore) : Nat {
    Trie.size(store)
  };

  func convertBeamTrieToArray(store : BeamStore) : [BeamModel] {
    Trie.toArray<BeamId, BeamModel, BeamModel>(
      store,
      func(key, value) : BeamModel {
        value
      }
    )
  };

  // {numBeam, date}
  public func queryBeamDate(store : BeamStore) : [BeamDateMetric] {
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
  }

}

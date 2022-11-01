import Trie "mo:base/Trie";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Array "mo:base/Array";

import BeamOutType "./BeamOutType";

import DateTimeUtil "../../utils/DateTimeUtil";

module BeamOutStoreHelper {

  type BeamOutId = BeamOutType.BeamOutId;
  type BeamOutModel = BeamOutType.BeamOutModel;
  type BeamOutStore = BeamOutType.BeamOutStore;
  type BeamOutDateMetric = BeamOutType.BeamOutDateMetric;

  public func findBeamOutById(beamOutStore : BeamOutStore, id : BeamOutId) : ?BeamOutModel {
    return Trie.find<BeamOutId, BeamOutModel>(beamOutStore, BeamOutType.idKey(id), Nat32.equal)
  };

  public func updateBeamOutStore(beamOutStore : BeamOutStore, beamOut : BeamOutModel) : BeamOutStore {
    let newStore = Trie.put(
      beamOutStore,
      BeamOutType.idKey(beamOut.id),
      Nat32.equal,
      beamOut
    ).0;
    return newStore
  };

  public func queryTotalBeamOut(store : BeamOutStore) : Nat {
    Trie.size(store)
  };

  func convertBeamOutTrieToArray(store : BeamOutStore) : [BeamOutModel] {
    Trie.toArray<BeamOutId, BeamOutModel, BeamOutModel>(
      store,
      func(key, value) : BeamOutModel {
        value
      }
    )
  };

  public func queryBeamOutDate(store : BeamOutStore) : [BeamOutDateMetric] {
    var dateTrie : Trie.Trie<Text, Nat> = Trie.empty();
    let beamOutArray = convertBeamOutTrieToArray(store);

    for (beamOut in beamOutArray.vals()) {
      let dateTimeString = DateTimeUtil.dateToCalendarDayText(beamOut.createdAt);
      let matched = Trie.get<Text, Nat>(
        dateTrie,
        BeamOutType.textKey(dateTimeString),
        Text.equal
      );

      let resultCount = switch matched {
        case null 1;
        case (?count) count + 1
      };

      let result = Trie.put<Text, Nat>(dateTrie, BeamOutType.textKey(dateTimeString), Text.equal, resultCount);
      dateTrie := result.0
    };

    let result = Trie.toArray<Text, Nat, BeamOutDateMetric>(
      dateTrie,
      func(key, value) : BeamOutDateMetric {
        { dateString = key; numURL = value }
      }
    );

    let sortByFunc = BeamOutType.compareByDateString;
    Array.sort<BeamOutDateMetric>(result, sortByFunc)
  }

}

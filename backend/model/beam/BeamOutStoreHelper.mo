import Array "mo:base/Array";
import Int "mo:base/Int";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Trie "mo:base/Trie";

import DateTimeUtil "../../utils/DateTimeUtil";
import BeamOutType "./BeamOutType";

module BeamOutStoreHelper {

  type BeamOutId = BeamOutType.BeamOutId;
  type BeamOutModelV3 = BeamOutType.BeamOutModelV3;
  type BeamOutStoreV3 = BeamOutType.BeamOutStoreV3;
  type BeamOutModel = BeamOutType.BeamOutModel;
  type BeamOutStore = BeamOutType.BeamOutStore;
  type BeamOutDateMetric = BeamOutType.BeamOutDateMetric;

  public func findBeamOutById(beamOutStore : BeamOutStoreV3, id : BeamOutId) : ?BeamOutModelV3 {
    return Trie.find<BeamOutId, BeamOutModelV3>(beamOutStore, BeamOutType.idKey(id), Nat32.equal)
  };

  public func updateBeamOutStore(beamOutStore : BeamOutStoreV3, beamOut : BeamOutModelV3) : BeamOutStoreV3 {
    let newStore = Trie.put(
      beamOutStore,
      BeamOutType.idKey(beamOut.id),
      Nat32.equal,
      beamOut
    ).0;
    return newStore
  };

  public func queryTotalBeamOut(store : BeamOutStoreV3) : Nat {
    Trie.size(store)
  };

  func convertBeamOutTrieToArray(store : BeamOutStoreV3) : [BeamOutModelV3] {
    Trie.toArray<BeamOutId, BeamOutModelV3, BeamOutModelV3>(
      store,
      func(key, value) : BeamOutModelV3 {
        value
      }
    )
  };

  public func queryBeamOutDate(store : BeamOutStoreV3) : [BeamOutDateMetric] {
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
      func(key, value) : BeamOutDateMetric { { dateString = key; numURL = value } }
    );

    let sortByFunc = BeamOutType.compareByDateString;
    Array.sort<BeamOutDateMetric>(result, sortByFunc)
  };

  public func upgradeBeamOutStore(oldStore : BeamOutStore) : BeamOutStoreV3 {
    Trie.mapFilter<BeamOutId, BeamOutModel, BeamOutModelV3>(
      oldStore,
      func(beamOutId, old) : ?BeamOutModelV3 {
        ?{
          id = old.id;
          createdAt = old.createdAt;
          updatedAt = old.updatedAt;
          tokenType = old.tokenType;
          amount = old.amount;
          recipient = old.recipient;
          durationNumDays = old.durationNumDays;
          beamOutType = #payment
        }
      }
    )
  }

}

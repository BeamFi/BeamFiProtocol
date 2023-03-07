import Array "mo:base/Array";
import Int "mo:base/Int";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Trie "mo:base/Trie";

import DateTimeUtil "../../utils/DateTimeUtil";
import BeamOutType "./BeamOutType";

module BeamOutStoreHelper {

  type BeamOutId = BeamOutType.BeamOutId;
  type BeamOutModelV2 = BeamOutType.BeamOutModelV2;
  type BeamOutStoreV2 = BeamOutType.BeamOutStoreV2;
  type BeamOutModel = BeamOutType.BeamOutModel;
  type BeamOutStore = BeamOutType.BeamOutStore;
  type BeamOutDateMetric = BeamOutType.BeamOutDateMetric;

  public func findBeamOutById(beamOutStore : BeamOutStoreV2, id : BeamOutId) : ?BeamOutModelV2 {
    return Trie.find<BeamOutId, BeamOutModelV2>(beamOutStore, BeamOutType.idKey(id), Nat32.equal)
  };

  public func updateBeamOutStore(beamOutStore : BeamOutStoreV2, beamOut : BeamOutModelV2) : BeamOutStoreV2 {
    let newStore = Trie.put(
      beamOutStore,
      BeamOutType.idKey(beamOut.id),
      Nat32.equal,
      beamOut
    ).0;
    return newStore
  };

  public func queryTotalBeamOut(store : BeamOutStoreV2) : Nat {
    Trie.size(store)
  };

  func convertBeamOutTrieToArray(store : BeamOutStoreV2) : [BeamOutModelV2] {
    Trie.toArray<BeamOutId, BeamOutModelV2, BeamOutModelV2>(
      store,
      func(key, value) : BeamOutModelV2 {
        value
      }
    )
  };

  public func queryBeamOutDate(store : BeamOutStoreV2) : [BeamOutDateMetric] {
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

  public func upgradeBeamOutStore(oldStore : BeamOutStore) : BeamOutStoreV2 {
    Trie.mapFilter<BeamOutId, BeamOutModel, BeamOutModelV2>(
      oldStore,
      func(beamOutId, old) : ?BeamOutModelV2 {
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

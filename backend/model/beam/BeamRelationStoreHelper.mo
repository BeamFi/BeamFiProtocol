import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Trie "mo:base/Trie";

import EscrowType "../escrow/EscrowType";
import BeamType "./BeamType";

module BeamRelationStoreHelper {

  type BeamRelationObjId = BeamType.BeamRelationObjId;
  type BeamRelationStore = BeamType.BeamRelationStore;
  type BeamId = BeamType.BeamId;

  public func findBeamIdByRelId(store : BeamRelationStore, objId : BeamRelationObjId) : ?BeamId {
    return Trie.find<BeamRelationObjId, BeamId>(store, BeamType.relIdKey(objId), Text.equal)
  };

  public func updateBeamRelationStore(store : BeamRelationStore, beamId : BeamId, objId : BeamRelationObjId) : BeamRelationStore {
    let newStore = Trie.put(
      store,
      BeamType.relIdKey(objId),
      Text.equal,
      beamId
    ).0;
    return newStore
  }
}

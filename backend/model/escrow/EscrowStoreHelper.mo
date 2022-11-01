import Trie "mo:base/Trie";
import TrieSet "mo:base/TrieSet";
import Nat32 "mo:base/Nat32";
import Array "mo:base/Array";
import List "mo:base/List";
import Principal "mo:base/Principal";

import EscrowType "./EscrowType";

module EscrowStoreHelper {

  type EscrowStore = EscrowType.EscrowStore;
  type BeamEscrowPPStore = EscrowType.BeamEscrowPPStore;

  type EscrowContract = EscrowType.EscrowContract;
  type BeamEscrowContract = EscrowType.BeamEscrowContract;
  type EscrowId = EscrowType.EscrowId;
  type TokenAmount = EscrowType.TokenAmount;
  type TokenType = EscrowType.TokenType;

  public func findEscrowContractById(escrowStore : EscrowStore, id : EscrowId) : ?EscrowContract {
    return Trie.find<EscrowId, EscrowContract>(escrowStore, EscrowType.idKey(id), Nat32.equal)
  };

  public func loadAllEscrowContract(escrowStore : EscrowStore, tokenType : TokenType) : [EscrowContract] {
    var escrowArray = Trie.toArray<EscrowId, EscrowContract, EscrowContract>(
      escrowStore,
      func(id, escrow) : EscrowContract {
        escrow
      }
    );
    escrowArray := Array.filter<EscrowContract>(
      escrowArray,
      func(escrow) : Bool {
        escrow.tokenType == tokenType
      }
    );

    let sortByFunc = EscrowType.compareByCreatedAt;
    Array.sort<EscrowContract>(escrowArray, sortByFunc)
  };

  public func loadMyBeams(beamStore : BeamEscrowPPStore, escrowStore : EscrowStore, pp : Principal) : [BeamEscrowContract] {
    let escrowArrayOp = findEscrowsByPP(beamStore, pp);

    switch escrowArrayOp {
      case null [];
      case (?myEscrowArray) {
        let escrowArray = Array.mapFilter<EscrowId, BeamEscrowContract>(
          myEscrowArray,
          func(escrowId) : ?BeamEscrowContract {
            Trie.find<EscrowId, EscrowContract>(escrowStore, EscrowType.idKey(escrowId), Nat32.equal)
          }
        );

        let sortByFunc = EscrowType.compareByBeamEscrowCreatedAt;
        Array.sort<BeamEscrowContract>(escrowArray, sortByFunc)
      }
    }
  };

  public func loadMyBeamEscrow(beamStore : BeamEscrowPPStore, escrowStore : EscrowStore, pp : Principal, escrowId : EscrowId) : ?BeamEscrowContract {
    let escrowArrayOp = findEscrowsByPP(beamStore, pp);

    switch escrowArrayOp {
      case null null;
      case (?myEscrowArray) {
        let escrowList = List.fromArray<EscrowId>(myEscrowArray);
        let hasEscrowId = List.some<EscrowId>(
          escrowList,
          func(id) : Bool {
            id == escrowId
          }
        );

        if (hasEscrowId) {
          Trie.find<EscrowId, EscrowContract>(escrowStore, EscrowType.idKey(escrowId), Nat32.equal)
        } else {
          null
        }
      }
    }
  };

  public func findEscrowsByPP(store : BeamEscrowPPStore, pp : Principal) : ?[EscrowId] {
    return Trie.find<Principal, [EscrowId]>(store, EscrowType.ppKey(pp), Principal.equal)
  };

  public func addEscrowToBeamEscrowPPStore(store : BeamEscrowPPStore, pp : Principal, escrowId : EscrowId) : BeamEscrowPPStore {
    let escrowListOp = findEscrowsByPP(store, pp);

    let escrowList : [EscrowId] = do {
      switch escrowListOp {
        case null [escrowId];
        case (?myEscrowList) {
          var escrowIdSet = TrieSet.fromArray<EscrowId>(myEscrowList, EscrowType.escrowIdHash, EscrowType.escrowIdEqual);
          escrowIdSet := TrieSet.put<EscrowId>(escrowIdSet, escrowId, EscrowType.escrowIdHash(escrowId), EscrowType.escrowIdEqual);
          TrieSet.toArray<EscrowId>(escrowIdSet)
        }
      }
    };

    let newStore = updateBeamEscrowPPStore(store, pp, escrowList);
    return newStore
  };

  public func updateBeamEscrowPPStore(store : BeamEscrowPPStore, pp : Principal, newEscrowList : [EscrowId]) : BeamEscrowPPStore {
    let newStore = Trie.put(
      store,
      EscrowType.ppKey(pp),
      Principal.equal,
      newEscrowList
    ).0;
    return newStore
  };

  public func updateEscrowStore(escrowStore : EscrowStore, escrow : EscrowContract) : EscrowStore {
    let newStore = Trie.put(
      escrowStore,
      EscrowType.idKey(escrow.id),
      Nat32.equal,
      escrow
    ).0;
    return newStore
  };

  public func sumAllEscrowTokens(escrowStore : EscrowStore, tokenType : TokenType) : TokenAmount {
    let matchedTokensTrie = Trie.mapFilter<EscrowId, EscrowContract, TokenAmount>(
      escrowStore,
      func(id, escrow) : ?TokenAmount {
        if (escrow.tokenType == tokenType) {
          return ?escrow.escrowAmount
        };

        null
      }
    );

    let tokensArray = Trie.toArray<EscrowId, TokenAmount, TokenAmount>(
      matchedTokensTrie,
      func(id, tokenAmount) : TokenAmount {
        tokenAmount
      }
    );

    var sum : Nat64 = 0;
    for (tokenAmount in tokensArray.vals()) {
      sum += tokenAmount
    };

    sum
  };

}

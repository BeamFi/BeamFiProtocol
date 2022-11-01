import Prim "mo:prim";

import Env "../config/Env";

module Operation {

  public type CanisterMemoryInfo = {
    rts_version : Text;
    rts_memory_size : Nat;
    rts_heap_size : Nat;
    rts_total_allocation : Nat;
    rts_reclaimed : Nat;
    rts_max_live_size : Nat;
  };

  type CanisterSettings = {
    controllers: [Principal]
  };

  let ICManagement = actor "aaaaa-aa" : actor {
    canister_status : { canister_id : Principal } -> async {
      settings : CanisterSettings
    };
    update_settings: { canister_id: Principal; settings: CanisterSettings } -> async();
  };

  public func changeToMainController(canisterId: Principal) : async () {
    let controller = Env.getController();
    let settings: CanisterSettings = {controllers = [controller]};
    await ICManagement.update_settings({ canister_id = canisterId; settings: CanisterSettings });
  };

  public func changeController(canisterId: Principal, controller: Principal) : async () {
    let settings: CanisterSettings = {controllers = [controller]};
    await ICManagement.update_settings({ canister_id = canisterId; settings: CanisterSettings });
  };

  public func getCanisterMemoryInfo() : CanisterMemoryInfo {
    return {
        rts_version = Prim.rts_version();
        rts_memory_size = Prim.rts_memory_size();
        rts_heap_size = Prim.rts_heap_size();
        rts_total_allocation = Prim.rts_total_allocation();
        rts_reclaimed = Prim.rts_reclaimed();
        rts_max_live_size = Prim.rts_max_live_size();
    };
  };

  public func getCanisterUsedMemorySize() : Nat {
    return Prim.rts_total_allocation();
  };

}
import Principal "mo:base/Principal";

import BitcoinType "../bitcoin/BitcoinType";

module Env {
  // Manager - Internet Identity Anchor Id
  public let managerPrincipalId = "llaiv-papiv-e7wvh-njpek-4e57z-n3fgd-yu3ud-n7tqs-lr5ep-hut3y-wae";

  // Controller Principal Id
  public let controllerPrincipalId = "ktaun-mznjo-4w2qi-von4m-qodwj-hpm4t-d4yoo-dkzvz-7al2r-px72c-gae";

  // Client key
  public let clientKey = "kYWpQC_CJPXkQdz9zuAsnoYu-w_AFiq";

  // Beam Escrow Canister ID
  public let beamEscrowCanisterId = "rrkah-fqaaa-aaaaa-aaaaq-cai";

  // Monitor Agent Canister ID
  public let monitorAgentCanisterId = "x2dwq-7aaaa-aaaaa-aaaxq-cai";

  // Beam Canister ID
  public let beamCanisterId = "rno2w-sqaaa-aaaaa-aaacq-cai";

  // The Bitcoin network to connect to.
  // When developing locally this should be `Regtest`.
  // When deploying to the IC this should be `Testnet`.
  public let bitcoinNetwork = "Regtest";

  public func getBitcoinNetwork() : BitcoinType.Network {
    switch bitcoinNetwork {
      case ("Testnet") return #Testnet;
      case ("Regtest") return #Regtest;
      case _ return #Regtest
    }
  };

  public func getManager() : Principal {
    Principal.fromText(Env.managerPrincipalId)
  };

  public func getController() : Principal {
    Principal.fromText(Env.controllerPrincipalId)
  }
}

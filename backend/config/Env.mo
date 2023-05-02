import Principal "mo:base/Principal";

import BitcoinType "../bitcoin/BitcoinType";

module Env {
  // Client key
  public let clientKey = "#CLIENT_KEY#";

  // Beam Escrow Canister ID
  public let beamEscrowCanisterId = "#BEAM_ESCROW_CANISTER_ID#";

  // Monitor Agent Canister ID
  public let monitorAgentCanisterId = "#MONITORAGENT_CANISTER_ID#";

  // Beam Canister ID
  public let beamCanisterId = "#BEAM_CANISTER_ID#";

  // XTC Canister ID
  public let xtcCanisterId = "aanaa-xaaaa-aaaah-aaeiq-cai";

  // The Bitcoin network to connect to.
  // When developing locally this should be `Regtest`.
  // When deploying to the IC this should be `Testnet`.
  public let bitcoinNetwork = "#BITCOIN_NETWORK#";

  // Zoom Secret Token
  public let zoomSecretToken = "#ZOOM_SECRET_TOKEN#";

  public func getBitcoinNetwork() : BitcoinType.Network {
    switch bitcoinNetwork {
      case ("Testnet") return #Testnet;
      case ("Regtest") return #Regtest;
      case _ return #Regtest
    }
  };

}

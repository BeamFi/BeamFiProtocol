import R "mo:base/Result";
import Principal "mo:base/Principal";

import Ledger "canister:ledger";
import BeamEscrow "canister:beamescrow";

import Account "../model/ledger/Account";
import EscrowType "../model/escrow/EscrowType";
import EscrowStoreHelper "../model/escrow/EscrowStoreHelper";
import BitcoinType "../bitcoin/BitcoinType";
import BitcoinApi "../bitcoin/BitcoinApi";

import Http "../http/Http";
import Err "../utils/Error";
import Env "../config/Env";

actor MonitorAgent {

  type AccountIdentifier = Account.AccountIdentifier;
  type ErrorCode = { #escrow_token_owned_not_matched : Text };
  type Result<Ok, Err> = R.Result<Ok, Err>;

  type HttpRequest = Http.HttpRequest;
  type HttpResponse = Http.HttpResponse;

  type Satoshi = BitcoinType.Satoshi;

  // #### ICP Solvency
  public shared ({ caller }) func checkEscrowICPSolvency() : async Result<Text, ErrorCode> {
    await privateCheckEscrowICPSolvency()
  };

  func privateCheckEscrowICPSolvency() : async Result<Text, ErrorCode> {
    // Verify All Contracts ICP <= actual ICP tokens owned by this canister, requires await
    let canisterICPTokens = await getEscrowICPBalance();
    let sumAllEscrowTokenAmount = await BeamEscrow.sumAllEscrowTokens(#icp);

    let isMatched = EscrowType.verifyAllEscrowMatchedActual(
      sumAllEscrowTokenAmount,
      canisterICPTokens.e8s
    );
    if (not isMatched) {
      return #err(#escrow_token_owned_not_matched("The actual ICP owned by the BeamEscrow canister is smaller than the total escrow amount of all contracts"))
    };

    #ok("passed")
  };

  func getEscrowICPBalance() : async Ledger.Tokens {
    await Ledger.account_balance({ account = beamEscrowCanisterAccountId() })
  };

  func beamEscrowCanisterAccountId() : AccountIdentifier {
    Account.accountIdentifier(Principal.fromActor(BeamEscrow), Account.defaultSubaccount())
  };

  // #### BTC Solvency
  public shared ({ caller }) func checkEscrowBTCSolvency() : async Result<Text, ErrorCode> {
    await privateCheckEscrowBTCSolvency()
  };

  func privateCheckEscrowBTCSolvency() : async Result<Text, ErrorCode> {
    // Verify All Contracts BTC <= actual BTC tokens owned by this canister, requires await
    let btcAddress = await BeamEscrow.getBitcoinP2pkhAddress();
    let canisterBTCTokens = await getBitcoinBalance(btcAddress);
    let sumAllEscrowTokenAmount = await BeamEscrow.sumAllEscrowTokens(#btc);

    let isMatched = EscrowType.verifyAllEscrowMatchedActual(sumAllEscrowTokenAmount, canisterBTCTokens);
    if (not isMatched) {
      return #err(#escrow_token_owned_not_matched("The actual BTC owned by the canister is smaller than the total escrow amount of all contracts"))
    };

    #ok("passed")
  };

  func getBitcoinBalance(address : Text) : async Satoshi {
    let network = Env.getBitcoinNetwork();
    await BitcoinApi.get_balance(network, address)
  };

  // HTTP Request
  public query func http_request(req : HttpRequest) : async HttpResponse {
    let parsedURL = Http.parseURL(req.url);

    switch (parsedURL) {
      case (#err(_)) Http.BadRequest();
      case (#ok(endPoint, queryParams)) {
        if (not Http.checkKey(queryParams, "clientKey", Env.clientKey)) {
          return Http.BadRequest()
        };

        Http.TextContentUpgrade("upgrade to update call", true)
      }
    }
  };

  public func http_request_update(req : HttpRequest) : async HttpResponse {
    let parsedURL = Http.parseURL(req.url);

    switch (parsedURL) {
      case (#err(_)) Http.BadRequest();
      case (#ok(endPoint, queryParams)) {
        switch (endPoint) {
          case "/icp" {
            let result = await privateCheckEscrowICPSolvency();

            switch result {
              case (#ok _) Http.TextContent("passed");
              case (#err _) Http.ServerError()
            }
          };
          case "/btc" {
            let result = await privateCheckEscrowBTCSolvency();

            switch result {
              case (#ok _) Http.TextContent("passed");
              case (#err _) Http.ServerError()
            }
          };
          case _ Http.BadRequest()
        }
      }
    }
  };

}

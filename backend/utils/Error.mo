module Error {

  public type ErrorCode = {
    #escrow_payment_not_found : Text;
    #escrow_contract_verification_failed : Text;
    #escrow_token_owned_not_matched : Text;
    #escrow_contract_not_found : Text;
    #escrow_beam_failed : Text
  }

}

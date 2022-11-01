import Random "mo:base/Random";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";

module NumberUtil {

  /**
    Generate random number with the specified number of digits.
    E.g Given 6, it generates a 6 digits number between 100000 and 999999
  */
  public func generateRandomDigits(numDigits: Nat32) : async ?Nat32 {
    do ? {
      let entropy = await Random.blob();
      let finite = Random.Finite(entropy);

      var result: Nat32 = 0;
      var i: Nat32 = 0;

      while (i < numDigits) {
        let generated: Nat8 = finite.byte() !;
        let generatedNat32 = Nat32.fromNat(Nat8.toNat(generated));

        let number: Nat32 = Nat32.rem(generatedNat32, 10) * Nat32.pow(10, i);
        result += number;
        
        i += 1;
      };

      let minValue = Nat32.pow(10, numDigits-1);
      if (result < minValue) {
        result += minValue;
      };

      result;
    }
  }

}
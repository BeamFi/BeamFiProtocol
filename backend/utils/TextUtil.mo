import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Char "mo:base/Char";
import Iter "mo:base/Iter";

module TextUtil {

  public func textToNat(txt : Text) : ?Nat {
    if (txt.size() == 0) {
      return null
    };

    let chars = txt.chars();

    var num : Nat = 0;
    for (v in chars) {
      let charToNum = Nat32.toNat(Char.toNat32(v) -48);
      assert (charToNum >= 0 and charToNum <= 9);
      num := num * 10 + charToNum
    };

    ?num
  };

  public func firstNumChars(text : Text, numChars : Nat) : Text {
    let size = Text.size(text);
    var count = 0;
    var newText = "";

    label loopText for (char in Text.toIter(text)) {
      newText := newText # Text.fromChar(char);
      count += 1;

      if (count >= numChars) break loopText
    };

    newText
  };

  public func padStart(text : Text, toNumChars : Nat, padString : Text) : Text {
    let textSize = Text.size(text);
    if (textSize >= toNumChars) {
      return text
    };

    var startString = "";
    let numIter : Nat = toNumChars - textSize;
    let iter = Iter.range(1, numIter);

    for (val in iter) {
      startString := startString # padString
    };

    startString # text
  }
}

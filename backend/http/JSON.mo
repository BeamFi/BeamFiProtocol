import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import JSONParser "mo:JSON/JSON";

module JSON {

  let jsonOpen = "{";
  let arrayOpen = "\": [";
  let arrayClose = "]";
  let jsonClose = "}";

  public type KeyValueText = Text;
  public type KeyValueList = List.List<KeyValueText>;

  public func createArray(topKey : Text, kvList : KeyValueList) : Text {
    let headlessText = createHeadlessArray(topKey, kvList);

    let jsonText = jsonOpen # headlessText # jsonClose;
    return jsonText
  };

  public func createHeadlessArray(topKey : Text, kvList : KeyValueList) : Text {
    if (List.isNil(kvList)) {
      return "\"" # topKey # arrayOpen # arrayClose
    };

    let textIter = Iter.fromList(kvList);
    let arrayTxt = Text.join(",", textIter);

    "\"" # topKey # arrayOpen # arrayTxt # arrayClose
  };

  public func addKeyInt(key : Text, value : Int, accumList : KeyValueList) : KeyValueList {
    addKeyText(key, Int.toText(value), accumList)
  };

  public func addKeyNat32(key : Text, value : Nat32, accumList : KeyValueList) : KeyValueList {
    addKeyText(key, Nat32.toText(value), accumList)
  };

  public func createKeyNat32(key : Text, value : Nat32) : Text {
    "\"" # key # "\": " # "\"" # Nat32.toText(value) # "\""
  };

  public func createKeyText(key : Text, value : Text) : Text {
    "\"" # key # "\": " # "\"" # value # "\""
  };

  public func addKeyOptNat32(key : Text, value : ?Nat32, accumList : KeyValueList) : KeyValueList {
    switch value {
      case null accumList;
      case (?myValue) {
        addKeyText(key, Nat32.toText(myValue), accumList)
      }
    }
  };

  public func addKeyOptText(key : Text, value : ?Text, accumList : KeyValueList) : KeyValueList {
    switch value {
      case null accumList;
      case (?myValue) {
        addKeyText(key, myValue, accumList)
      }
    }
  };

  public func addKeyText(key : Text, value : Text, accumList : KeyValueList) : KeyValueList {
    let newKeyValue : KeyValueText = "\"" # key # "\": " # "\"" # value # "\"";
    List.push(newKeyValue, accumList)
  };

  public func addKeyNat(key : Text, value : Nat, accumList : KeyValueList) : KeyValueList {
    let newKeyValue : KeyValueText = "\"" # key # "\": " # Nat.toText(value);
    List.push(newKeyValue, accumList)
  };

  public func extractObject(key : Text, obj : [(Text, JSONParser.JSON)]) : ?[(Text, JSONParser.JSON)] {
    for (i in Iter.range(0, obj.size() - 1)) {
      switch (obj[i]) {
        case ((jsonKey, #Object(w))) {
          if (jsonKey == key) {
            return ?w
          }
        };
        case (_)()
      }
    };

    return null
  };

  public func extractString(key : Text, obj : [(Text, JSONParser.JSON)]) : ?Text {
    for (i in Iter.range(0, obj.size() - 1)) {
      let (jsonKey, jsonValue) = obj[i];
      switch (obj[i]) {
        case ((jsonKey, #String(w))) {
          if (jsonKey == key) {
            return ?w
          }
        };
        case (_)()
      }
    };

    return null
  };

}

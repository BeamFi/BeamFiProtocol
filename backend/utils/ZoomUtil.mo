import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Text "mo:base/Text";
import HMAC "mo:crypto/HMAC";
import SHA256 "mo:crypto/SHA/SHA256";
import HexUtil "mo:encoding/Hex";
import JSON "mo:JSON/JSON";

import Env "../config/Env";
import Http "../http/Http";
import JSONUtil "../http/JSON";

module ZoomUtil {

  type JSONText = Http.JSONText;
  type HeaderField = Http.HeaderField;
  type Hex = HexUtil.Hex;

  let ZoomHeaderSignature = "x-zm-signature";
  let ZoomHeaderTimestamp = "x-zm-request-timestamp";

  public func verifySignature(jsonStr : JSONText, headers : [HeaderField]) : Bool {
    let signatureOp = Http.findHeader(headers, ZoomHeaderSignature);
    let expSignature = switch (signatureOp) {
      case (null) { return false };
      case (?v) { v }
    };

    let timestampOp = Http.findHeader(headers, ZoomHeaderTimestamp);
    let timestamp = switch (timestampOp) {
      case (null) { return false };
      case (?v) { v }
    };

    let message = "v0:" # timestamp # ":" # jsonStr;
    let hashForVerify = createHash(message, Env.zoomSecretToken);
    let signature = "v0=" # hashForVerify;

    signature == expSignature
  };

  public func processValidationRequest(jsonStr : Text) : JSONText {
    let plainTokenOp : ?Text = extractPlainToken(jsonStr);
    let plainToken = switch (plainTokenOp) {
      case (null) return "";
      case (?v) v
    };

    let encryptedToken = createHash(plainToken, Env.zoomSecretToken);
    var kvList = JSONUtil.addKeyText("encryptedToken", encryptedToken, List.nil());
    kvList := JSONUtil.addKeyText("plainToken", plainToken, kvList);

    let kvIter = Iter.fromList(kvList);
    "{" # Text.join(",", kvIter) # "}"
  };

  public func createHash(message : Text, zoomSecretToken : Text) : Hex {
    let salt = Blob.toArray(Text.encodeUtf8(zoomSecretToken));

    let h = HMAC.New(SHA256.New, salt);
    h.write(Blob.toArray(Text.encodeUtf8(message)));

    let hash = h.sum([]);
    HexUtil.encode(hash)
  };

  public func extractEvent(jsonStr : Text, pos : Nat) : ?Text {
    switch (JSON.parse(jsonStr)) {
      case (null) return null;
      case (?v) {
        switch (v) {
          case (#Object(v)) {
            if (v.size() <= pos) return null;
            switch (v[pos]) {
              case (("event", #String(v))) {
                return ?v
              };
              case (_) return null
            }

          };
          case (_) return null
        }
      }
    };

    return null
  };

  public func extractPlainToken(jsonStr : Text) : ?Text {
    switch (JSON.parse(jsonStr)) {
      case (null) return null;
      case (?v) {
        switch (v) {
          case (#Object(v)) {
            if (v.size() < 1) return null;

            switch (v[0]) {
              case (("payload", #Object(v))) {
                if (v.size() < 1) return null;

                switch (v[0]) {
                  case (("plainToken", #String(v))) {
                    return ?v
                  };
                  case (_) return null
                }
              };
              case (_) return null
            }
          };
          case (_) return null
        }
      }
    };

    return null
  };

  func extractObject(key : Text, obj : [(Text, JSON.JSON)]) : ?[(Text, JSON.JSON)] {
    for (i in Iter.range(0, 20)) {
      switch (obj[i]) {
        case ((key, #Object(w))) {
          return ?w
        };
        case (_)()
      }
    };

    return null
  };

  func extractString(key : Text, obj : [(Text, JSON.JSON)]) : ?Text {
    for (i in Iter.range(0, 20)) {
      switch (obj[i]) {
        case ((key, #String(w))) {
          return ?w
        };
        case (_)()
      }
    };

    return null
  };

  public func extractMeetingId(jsonStr : Text) : ?Text {
    do ? {
      let v = switch (JSON.parse(jsonStr)) {
        case (null) return null;
        case (?v) v
      };

      let w = switch (v) {
        case (#Object(v)) v;
        case (_) return null
      };

      let y = extractObject("payload", w)!;
      let z = extractObject("object", y)!;
      let m = extractString("id", z)!;

      m
    }
  }

}

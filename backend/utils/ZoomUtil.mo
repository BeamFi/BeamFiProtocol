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
    do ? {
      let v = JSON.parse(jsonStr)!;
      let w = switch (v) {
        case (#Object(v)) v;
        case (_) return null
      };

      JSONUtil.extractString("event", w)!
    }
  };

  public func extractPlainToken(jsonStr : Text) : ?Text {
    do ? {
      let v = JSON.parse(jsonStr)!;
      let w = switch (v) {
        case (#Object(v)) v;
        case (_) return null
      };

      let y = JSONUtil.extractObject("payload", w)!;
      JSONUtil.extractString("plainToken", y)!
    }
  };

  public func extractMeetingId(jsonStr : Text) : ?Text {
    do ? {
      let v = JSON.parse(jsonStr)!;
      let w = switch (v) {
        case (#Object(v)) v;
        case (_) return null
      };

      let y = JSONUtil.extractObject("payload", w)!;
      let z = JSONUtil.extractObject("object", y)!;
      JSONUtil.extractString("id", z)!
    }
  }

}

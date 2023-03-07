import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Text "mo:base/Text";
import HMAC "mo:crypto/HMAC";
import SHA256 "mo:crypto/SHA/SHA256";
import JSON "mo:JSON/JSON";

import Env "../config/Env";
import Http "../http/Http";
import JSONUtil "../http/JSON";

module ZoomUtil {

  type JSONText = Http.JSONText;

  public func processValidationRequest(jsonStr : Text) : JSONText {
    let plainTokenOp : ?Text = extractPlainToken(jsonStr);
    let plainToken = switch (plainTokenOp) {
      case (null) { return "" };
      case (?v) { v }
    };

    let encryptedTokenOP = createValidationHash(plainToken, Env.zoomSecretToken);
    var kvList = JSONUtil.addKeyOptText("encryptedToken", encryptedTokenOP, List.nil());
    // kvList := JSONUtil.addKeyText("plainToken", plainToken, kvList);

    let kvIter = Iter.fromList(kvList);
    "{" # Text.join(",", kvIter) # "}"
  };

  public func createValidationHash(plainToken : Text, zoomSecretToken : Text) : ?Text {
    let salt = Blob.toArray(Text.encodeUtf8(zoomSecretToken));

    let h = HMAC.New(SHA256.New, salt);
    h.write(Blob.toArray(Text.encodeUtf8(plainToken)));

    let hash = h.sum([]);
    Text.decodeUtf8(Blob.fromArray(hash))
  };

  public func extractEvent(jsonStr : Text) : ?Text {
    switch (JSON.parse(jsonStr)) {
      case (null) { return null };
      case (?v) {
        switch (v) {
          case (#Object(v)) {
            if (v.size() != 3) return null;

            switch (v[2]) {
              case (("event", #String(v))) {
                return ?v
              };
              case (_) { return null }
            }
          };
          case (_) { return null }
        }
      }
    };

    return null
  };

  public func extractPlainToken(jsonStr : Text) : ?Text {
    switch (JSON.parse(jsonStr)) {
      case (null) { return null };
      case (?v) {
        switch (v) {
          case (#Object(v)) {
            switch (v[0]) {
              case (("payload", #Object(v))) {
                switch (v[0]) {
                  case (("plainToken", #String(v))) {
                    return ?v
                  };
                  case (_) { return null }
                }
              };
              case (_) { return null }
            }
          };
          case (_) { return null }
        }
      }
    };

    return null
  }

}

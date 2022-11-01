import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import R "mo:base/Result";
import Text "mo:base/Text";
import Blob "mo:base/Blob";

module Http {

  type Result<Ok, Err> = R.Result<Ok, Err>;

  public type HeaderField = (Text, Text);

  public type HttpRequest = {
    method : Text;
    url : Text;
    headers : [HeaderField];
    body : Blob
  };

  public type HttpResponse = {
    status_code : Nat16;
    headers : [HeaderField];
    body : Blob;
    upgrade : Bool
  };

  public type ParamName = Text;
  public type ParaValue = Text;
  public type QueryParam = (ParamName, ParaValue);

  public type FileObject = [Nat8];
  public type MimeType = Text;
  public type JSONText = Text;

  public func NotFound() : HttpResponse {
    {
      status_code = 404;
      headers = [];
      body = Text.encodeUtf8("Not supported");
      upgrade = false
    }
  };

  public func BadRequest() : HttpResponse {
    {
      status_code = 400;
      headers = [];
      body = Text.encodeUtf8("Invalid request");
      upgrade = false
    }
  };

  public func ServerError() : HttpResponse {
    {
      status_code = 500;
      headers = [];
      body = Text.encodeUtf8("Server Error");
      upgrade = false
    }
  };

  public func HtmlContent(content : Text) : HttpResponse {
    {
      status_code = 200;
      headers = [
        ("Content-Type", "text/html"),
        ("Content-Length", Nat.toText(content.size()))
      ];
      body = Text.encodeUtf8(content);
      upgrade = false
    }
  };

  public func TextContent(content : Text) : HttpResponse {
    {
      status_code = 200;
      headers = [
        ("Content-Type", "text/plain"),
        ("Content-Length", Nat.toText(content.size()))
      ];
      body = Text.encodeUtf8(content);
      upgrade = false
    }
  };

  public func TextContentUpgrade(content : Text, upgrade : Bool) : HttpResponse {
    {
      status_code = 200;
      headers = [
        ("Content-Type", "text/plain"),
        ("Content-Length", Nat.toText(content.size()))
      ];
      body = Text.encodeUtf8(content);
      upgrade = upgrade
    }
  };

  public func JsonContent(content : JSONText, upgrade : Bool) : HttpResponse {
    {
      status_code = 200;
      headers = [
        ("Content-Type", "application/json;charset=utf-8"),
        ("Content-Length", Nat.toText(content.size()))
      ];
      body = Text.encodeUtf8(content);
      upgrade = upgrade
    }
  };

  public func MimeContent(fileObject : FileObject, mimeType : MimeType) : HttpResponse {
    let blobContent = Blob.fromArray(fileObject);

    {
      status_code = 200;
      headers = [
        ("Content-Type", mimeType),
        ("Content-Length", Nat.toText(blobContent.size()))
      ];
      body = blobContent;
      upgrade = false
    }
  };

  public func ImmutablePrivateContent(fileObject : FileObject, mimeType : MimeType) : HttpResponse {
    let blobContent = Blob.fromArray(fileObject);

    {
      status_code = 200;
      headers = [
        ("Content-Type", mimeType),
        ("Content-Length", Nat.toText(blobContent.size())),
        ("Cache-Control", "private, max-age=31536000, immutable")
      ];
      body = blobContent;
      upgrade = false
    }
  };

  public func parseURL(str : Text) : Result<(Text, [QueryParam]), Text> {
    let ps : [Text] = Iter.toArray(Text.split(str, #char '?'));

    if (ps.size() != 2) {
      if (ps.size() == 1) {
        return #ok((ps[0], []))
      };

      return #err("Invalid path: " # str)
    };

    let qStr : [Text] = Iter.toArray(Text.split(ps[1], #char '&'));
    let params = Array.init<QueryParam>(qStr.size(), ("", ""));

    for (i in qStr.keys()) {
      let p : [Text] = Iter.toArray(Text.split(qStr[i], #char '='));

      if (ps.size() != 2) {
        return #err("Invalid query string parameter: " # qStr[i])
      };

      params[i] := (p[0], p[1])
    };

    return #ok((ps[0], Array.freeze(params)))
  };

  public func checkKey(params : [QueryParam], keyName : Text, key : Text) : Bool {
    for ((name, value) in params.vals()) {
      if (name == keyName) {
        return value == key
      }
    };

    false
  };

}

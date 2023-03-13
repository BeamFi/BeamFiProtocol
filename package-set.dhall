let upstream = https://github.com/dfinity/vessel-package-set/releases/download/mo-0.6.21-20220215/package-set.dhall
let Package =
  { name : Text, version : Text, repo : Text, dependencies : List Text }

let
  -- HMAC SHA256
  additions =
    [
      { name = "crypto"
      , repo = "https://github.com/aviate-labs/crypto.mo"
      , version = "v0.3.1"
      , dependencies = ["base-0.7.3", "array", "encoding"] : List Text
      },
      { name = "base-0.7.3"
      , repo = "https://github.com/dfinity/motoko-base"
      , version = "moc-0.7.3"
      , dependencies = [] : List Text
      },
      { name = "array"
      , repo = "https://github.com/aviate-labs/array.mo"
      , version = "v0.2.1"
      , dependencies = [ "base-0.7.3" ] : List Text
      },
      { name = "encoding"
      , repo = "https://github.com/aviate-labs/encoding.mo"
      , version = "v0.4.1"
      , dependencies = [ "base-0.7.3", "array" ] : List Text
      },
      { name = "JSON"
      , repo = "https://github.com/aviate-labs/json.mo"
      , version = "v0.2.1"
      , dependencies = [ "base-0.7.3", "parser-combinators" ] : List Text
      },
      { name = "parser-combinators"
      , repo = "https://github.com/aviate-labs/parser-combinators.mo"
      , version = "v0.1.2"
      , dependencies = [ "base-0.7.3" ] : List Text
      }
    ] 
    
    : List Package

let overrides =
  [] : List Package

in upstream # additions # overrides
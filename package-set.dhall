let upstream = https://github.com/dfinity/vessel-package-set/releases/download/mo-0.6.21-20220215/package-set.dhall
let Package =
  { name : Text, version : Text, repo : Text, dependencies : List Text }

let
  -- HMAC SHA256
  additions =
    [
      { name = "crypto.mo"
      , repo = "https://github.com/aviate-labs/crypto.mo"
      , version = "v0.3.1"
      , dependencies = [] : List Text
      }
    ] : List Package

let overrides =
  [] : List Package

in upstream # additions # overrides
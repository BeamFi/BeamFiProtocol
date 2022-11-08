# BeamFi Protocol

BeamFi Protocol is a realtime money streaming protocol.

# Author

Henry Chan
henry@kinwo.net
Twitter: @kinwo

## Setting up Github Action CI / CD

Get the string using commands below then put it into Github Secrets.
Note: Replace default by the identity name you need.

E.g. icprod

### DFX_IDENTITY

```
awk 'NF {sub(/\r/, ""); printf "%s\\r\\n",$0;}' ~/.config/dfx/identity/icprod/identity.pem
```

### DFX_WALLETS

```
cat ~/.config/dfx/identity/icprod/wallets.json
```

Then replace identity name to "default".

E.g. if the identity name is icprod, change icprod to default in the JSON.

Output:

```
{
  "identities": {
    "icprod": {
      "ic": "xxxxxx"
    }
  }
}
```

Change to:

```
{
  "identities": {
    "default": {
      "ic": "xxxxx"
    }
  }
}
```

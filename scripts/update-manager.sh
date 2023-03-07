#!/usr/bin/env bash

echo Setting Internet Identity Anchor ID to $INTERNET_IDENTITY_ANCHOR_ID
sed -i.bak 's/#INTERNET_IDENTITY_ANCHOR_ID#/'"$INTERNET_IDENTITY_ANCHOR_ID"'/g' './backend/config/Env.mo'

echo Setting Controller Principal ID to $CONTROLLER_PRINCIPAL_ID
sed -i.bak 's/#CONTROLLER_PRINCIPAL_ID#/'"$CONTROLLER_PRINCIPAL_ID"'/g' './backend/config/Env.mo'

echo Setting Client Key to $CLIENT_KEY
sed -i.bak 's/#CLIENT_KEY#/'"$CLIENT_KEY"'/g' './backend/config/Env.mo'

echo Setting Beam Escrow Canister ID to $BEAM_ESCROW_CANISTER_ID
sed -i.bak 's/#BEAM_ESCROW_CANISTER_ID#/'"$BEAM_ESCROW_CANISTER_ID"'/g' './backend/config/Env.mo'

echo Setting Monitor Agent Canister ID to $MONITORAGENT_CANISTER_ID
sed -i.bak 's/#MONITORAGENT_CANISTER_ID#/'"$MONITORAGENT_CANISTER_ID"'/g' './backend/config/Env.mo'

echo Setting Beam Canister ID to $BEAM_CANISTER_ID
sed -i.bak 's/#BEAM_CANISTER_ID#/'"$BEAM_CANISTER_ID"'/g' './backend/config/Env.mo'

echo Setting Bitcoin Network to $BITCOIN_NETWORK
sed -i.bak 's/#BITCOIN_NETWORK#/'"$BITCOIN_NETWORK"'/g' './backend/config/Env.mo'

echo Setting Zoom Secret Token to $ZOOM_SECRET_TOKEN
sed -i.bak 's/#ZOOM_SECRET_TOKEN#/'"$ZOOM_SECRET_TOKEN"'/g' './backend/config/Env.mo'

rm ./backend/config/Env.mo.bak
#!/bin/sh -l

run_cmd() 
{
  echo $1
  cmd=$1
  eval $cmd
  exitStatus=$?
  if [ $exitStatus -ne 0 ] 
  then
      echo "1st attempt error: "
      echo $exitStatus

      echo "Rety once: "
      eval $cmd
      exitStatus=$?

      if [ $exitStatus -ne 0 ] 
      then
        echo "2nd attempt error: "
        echo $exitStatus
        exit $exitStatus
      fi
  fi
}

# Deploy & Upgrade Canisters
npm install -g yes
mkdir -p .dfx/ic/canisters/idl
yes yes | dfx deploy beamout --network ic --mode reinstall
yes yes | dfx deploy beamescrow --network ic --mode reinstall
yes yes | dfx deploy beam --network ic --mode reinstall
yes yes | dfx deploy monitoragent --network ic --mode reinstall
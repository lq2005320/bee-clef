#!/usr/bin/env bash
###
 # @Author: your name
 # @Date: 2021-06-09 11:39:24
 # @LastEditTime: 2021-06-09 11:39:52
 # @LastEditors: your name
 # @Description: In User Settings Edit
 # @FilePath: /bee-clef/packaging/cashout62.sh
###

bee_absolute_path=/mnt/sdb1/bee
infos=`grep -r "debug-api-addr" $bee_absolute_path/*/bee.yaml $pwd`

array=(${infos// / })
for var in ${array[@]}
do
  nodepath=$(echo ${var%%:*})
  node=$(echo ${nodepath%/*})
  nodesort=$(echo ${node##*/})
  port=$(echo ${var##*:})

  DEBUG_API=http://localhost:$port
  MIN_AMOUNT=100
  #[ -z ${DEBUG_API+x} ] && DEBUG_API=http://localhost:$port
  #[ -z ${MIN_AMOUNT+x} ] && MIN_AMOUNT=10000000000000000
  
  # cashout script for bee >= 0.6.0
  # note this is a simple bash script which might not work well or at all on some platforms
  # for a more robust interface take a look at https://github.com/ethersphere/swarm-cli
  # source https://gist.github.com/ralph-pichler/3b5ccd7a5c5cd0500e6428752b37e975
  function getPeers() {
    curl -s "$DEBUG_API/chequebook/cheque" | jq -r '.lastcheques | .[].peer'
  }
  
  function getUncashedAmount() {
    curl -s "$DEBUG_API/chequebook/cashout/$1" | jq '.uncashedAmount'
  }
  
  function cashout() {
    local peer=$1
    txHash=$(curl -s -XPOST "$DEBUG_API/chequebook/cashout/$peer" | jq -r .transactionHash)
    echo cashing out cheque for $peer in transaction $txHash >&2
  }
  
  function cashoutAll() {
    local minAmount=$1
    for peer in $(getPeers)
    do
      local uncashedAmount=$(getUncashedAmount $peer)
      if (( "$uncashedAmount" > $minAmount ))
      then
        echo "uncashed cheque for $peer ($uncashedAmount uncashed)" >&2
        cashout $peer
      fi
    done
  }
  
  function listAllUncashed() {
    for peer in $(getPeers)
    do
      local uncashedAmount=$(getUncashedAmount $peer)
      if (( "$uncashedAmount" > 0 ))
      then
	echo $peer $uncashedAmount
      fi
    done
  }
  
  case $1 in
  cashout)
    cashout $2
    ;;
  cashout-all)
    cashoutAll $MIN_AMOUNT
    ;;
  uncashed-for-peer)
    getUncashedAmount $2
    ;;
  list-uncashed|*)
    echo $nodesort
    listAllUncashed
    ;;
  esac
done

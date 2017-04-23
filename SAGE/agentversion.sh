#!/bin/sh
# check the version of the challenge agent on each machine
agentvers() {
	eval $(docker-machine env $1)
	echo $1 $(docker images brucehoff/challengedockeragent:latest -q)	
}
agentvers bm01
agentvers bm02
agentvers bm03
agentvers bm04
agentvers bm06
agentvers bm07
agentvers bm08
agentvers bm09
agentvers bm10
agentvers bm14
agentvers bm15
agentvers bm16
agentvers bm17
agentvers bm18
agentvers bm19
agentvers bm20
agentvers bm21
agentvers bm22
agentvers bm23


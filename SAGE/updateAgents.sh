#!/bin/bash

usage(){
	echo "Usage:"
	echo -e "\t$0 role scriptToRun machineNames"
	echo "Parameters: "
	echo -e "\trole: either 'train' or 'score'"
	echo -e "\tscriptToRun: name of script to run for setting up an individual machine"
	echo -e "\tmachineNames: space separated machine names e.g. bm01 bm02 bm03"
	exit 1
}

if [[(($# -lt 3))]]; then
	echo "TOO FEW ARGUMENTS: $#"
	usage 
fi

ROLE=$1
if [ ${ROLE} != "train" ] && [ ${ROLE} != "score" ]; then
	echo "INVALID ROLE: $ROLE"
	usage
fi

SCRIPT_TO_RUN=$2
#check script file exists
if [ ! -f $SCRIPT_TO_RUN ]; then
    echo "File: $SCRIPT_TO_RUN not found!"
    exit 1
fi



MACHINE_NAMES=${@:3}
#get list of current docker-machine names
VALID_NAMES=$(docker-machine ls -q)
#regex will be in fromat : ^(machineName1|machineName2|...|machineNameN)$
VALID_NAMES_REGEX="^($( echo "$VALID_NAMES" | paste -sd '|' - ))$"
#validate the passed parameters
for MACHINE_NAME in $MACHINE_NAMES; do
	if ! [[ $MACHINE_NAME =~ $VALID_NAMES_REGEX ]]; then
		echo "$MACHINE_NAME is not a valid docker-machine name. Please use names listed in 'docker-machine ls'"
		usage
		exit 1
	fi
done

checkForErrorExitCode(){
	local EXITCODE=$1
	local ERRROMESSAGE=$2
	if [ $EXITCODE -ne 0 ]; then
		echo $ERRROMESSAGE
	fi
}

#function to update each machine
updateMachine(){
	local DOCKER_STOP_WAIT_TIME=120
	local MACHINE_NAME=$1	
	echo "Updating machine: $MACHINE_NAME"
	
	# set docker-machine to point to the machine
	local DOCKEREVAL=$(docker-machine env $MACHINE_NAME)
	#check exit code here because eval always returns 0 even if the inside fails
	checkForErrorExitCode $? "failed to set docker-machine to $MACHINE_NAME"
	eval $DOCKEREVAL


	#docker stop and remove container
	local CONTAINER_ONE_NAME=$MACHINE_NAME-$ROLE-1
	local CONTAINER_TWO_NAME=$MACHINE_NAME-$ROLE-2

	#used to check if container exists
	docker inspect --format="{{ .State.Running }}" $CONTAINER_ONE_NAME 2> /dev/null #Don't care about it's error message
	#the previous command has a non-zero exit code if the container does not exist
	if [ $? -eq 0 ]; then #container exists
		docker stop $CONTAINER_ONE_NAME -t $DOCKER_STOP_WAIT_TIME
		checkForErrorExitCode $? "failed to stop container $CONTAINER_ONE_NAME"

		docker rm $CONTAINER_ONE_NAME
		checkForErrorExitCode $? "failed to remove container $CONTAINER_ONE_NAME"
	fi

	#used to check if container exists
	docker inspect --format="{{ .State.Running }}" $CONTAINER_TWO_NAME 2> /dev/null 
	if [ $? -eq 0 ]; then #container exists
		docker stop $CONTAINER_TWO_NAME -t $DOCKER_STOP_WAIT_TIME
		checkForErrorExitCode $? "failed to stop container $CONTAINER_TWO_NAME"
		
		docker rm $CONTAINER_TWO_NAME
		checkForErrorExitCode $? "failed to remove container $CONTAINER_TWO_NAME"
	fi

	#pull latest image
	docker pull brucehoff/challengedockeragent
	checkForErrorExitCode $? "failed to pull latest image"

	#TODO: remove untagged images
	#docker rmi $(docker images --filter "dangling=true" -q --no-trunc)

	#Run script to start the agent
	$SCRIPT_TO_RUN $ROLE 1
	checkForErrorExitCode $? "script failed: '!!'"
	$SCRIPT_TO_RUN $ROLE 2
	checkForErrorExitCode $? "script failed: '!!'"
	
	#activate nvml-cloudwatch
	docker stop nvml-cloudwatch
	docker rm nvml-cloudwatch
	docker pull docker.synapse.org/syn5644795/nvml-cloudwatch
	checkForErrorExitCode $? "failed to pull nvml-cloudwatch"

	docker run -d \
-e aws_access_key_id=$cloudwatch_aws_access_key_id \
-e aws_secret_access_key=$cloudwatch_aws_secret_access_key \
--device /dev/nvidia0:/dev/nvidia0 \
--device /dev/nvidia1:/dev/nvidia1 \
--device /dev/nvidia2:/dev/nvidia2 \
--device /dev/nvidia3:/dev/nvidia3 \
--device /dev/nvidiactl:/dev/nvidiactl \
--device /dev/nvidia-uvm:/dev/nvidia-uvm \
-v /usr/lib64/nvidia/libnvidia-ml.so:/usr/lib64/libnvidia-ml.so:ro \
-v /usr/lib64/nvidia/libnvidia-ml.so.1:/usr/lib64/libnvidia-ml.so.1:ro \
-v /usr/lib64/nvidia/libnvidia-ml.so.367.48:/usr/lib64/libnvidia-ml.so.367.48:ro \
--cpuset-cpus "0" \
--memory 512m \
--memory-swap 0m \
-h $(docker-machine active) \
--restart unless-stopped \
--name nvml-cloudwatch docker.synapse.org/syn5644795/nvml-cloudwatch 
		
	checkForErrorExitCode $? "failed to start nvml-cloudwatch"

	echo "Sucessfully updated: $MACHINE_NAME"
}

for MACHINE_NAME in $MACHINE_NAMES; do
	updateMachine $MACHINE_NAME
done

echo "Reverting to local docker host."
#revert to using local docker
eval $(docker-machine env -u)

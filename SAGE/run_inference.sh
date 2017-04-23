#!/bin/bash
#
# This script runs an inference submission on a challenge server directly.
# First use Docker Machine to 'point' the Docker client to the server daemon.
#
# Example: 
#	eval $(docker-machine env p28x00)
#	./run_inference.sh sc1 1 docker.synapse.org/foo/bar
#
export SUB_CHALL=$1
export AGENT_INDEX=$2
export IMAGE=$3

DOCKER_MACHINE_NAME=$(docker-machine active)
echo DOCKER_MACHINE_NAME=${DOCKER_MACHINE_NAME}
DOCKER_MACHINE_IP=$(docker-machine ip ${DOCKER_MACHINE_NAME})
echo DOCKER_MACHINE_IP=${DOCKER_MACHINE_IP}

IS_BM=false
IS_EC2=false
if [[ ${DOCKER_MACHINE_IP} = bm* ]]; then 
	IS_BM=true
elif [[ ${DOCKER_MACHINE_IP} = ec2* ]]; then 
	IS_EC2=true
else
	echo unexpected DOCKER_MACHINE_IP ${DOCKER_MACHINE_IP}
	exit 1
fi

if [[ ${AGENT_INDEX} = 1 ]]; then
	GPUS="/dev/nvidia0;/dev/nvidia1"
	FIRST_GPU_DEVICE_MOUNT="/dev/nvidia0:/dev/nvidia0"
	SECND_GPU_DEVICE_MOUNT="/dev/nvidia1:/dev/nvidia1"
	if [[ ${IS_BM} = true ]]; then
		AGENT_CPUS="0"
		CPUS="1-22"
		NUM_CPU_CORES=22
	else 
		AGENT_CPUS="0"
		CPUS="1-15"
		NUM_CPU_CORES=15
	fi
elif [[ ${AGENT_INDEX} = 2 ]]; then
	GPUS="/dev/nvidia2;/dev/nvidia3"
	FIRST_GPU_DEVICE_MOUNT="/dev/nvidia2:/dev/nvidia2"
	SECND_GPU_DEVICE_MOUNT="/dev/nvidia3:/dev/nvidia3"
	if [[ ${IS_BM} = true ]]; then
		AGENT_CPUS="24"
		CPUS="25-46"
		NUM_CPU_CORES=22
	else 
		AGENT_CPUS="16"
		CPUS="17-31"
		NUM_CPU_CORES=15
	fi
else 
	echo "INVALID AGENT_INDEX " ${AGENT_INDEX}
	exit 1
fi

let AGENT_INDEX_MINUS_1=$AGENT_INDEX-1

# the following are the same for all queues
TEMP_DIR=/data/tempDir${AGENT_INDEX_MINUS_1}
MODEL_STATE=/data/model${AGENT_INDEX_MINUS_1}
SCRATCH=/data/scratch${AGENT_INDEX_MINUS_1}
INFERENCE_OUTPUT=/data/inference${AGENT_INDEX_MINUS_1}

ssh ${DOCKER_MACHINE_NAME} touch ${INFERENCE_OUTPUT}/predictions.tsv

if [[ ${SUB_CHALL} = sc1 ]]; then
	export SC1_SCORING_DATA=/data/data/dm-challenge-dcm/SC1_leaderboard:/inferenceData
	export SC1_SCORING_IMAGE_METADATA_MOUNT=/data/data/metadata/SC1_leaderboard_images_crosswalk.tsv:/metadata/images_crosswalk.tsv
	export RO_VOLUME_MOUNTS="-v ${SC1_SCORING_DATA}:ro -v ${SC1_SCORING_IMAGE_METADATA_MOUNT}:ro "
	export ENTRY_POINT=/sc1_infer.sh
elif [[ ${SUB_CHALL} = sc2 ]]; then
	export SC2_SCORING_DATA=/data/data/dm-challenge-dcm/SC2_leaderboard:/inferenceData
	export SC2_SCORING_EXAM_METADATA_MOUNT=/data/data/metadata/SC2_leaderboard_exams_metadata.tsv:/metadata/exams_metadata.tsv
	export SC2_SCORING_IMAGE_METADATA_MOUNT=/data/data/metadata/SC2_leaderboard_images_crosswalk.tsv:/metadata/images_crosswalk.tsv
	export RO_VOLUME_MOUNTS="-v ${SC2_SCORING_DATA}:ro -v ${SC2_SCORING_EXAM_METADATA_MOUNT}:ro -v ${SC2_SCORING_IMAGE_METADATA_MOUNT}:ro "
	export ENTRY_POINT=/sc2_infer.sh
else 
	echo "INVALID sub-challenge " ${SUB_CHALL}
	exit 1
fi

docker run -d \
-v nvidia_driver_367.48:/usr/local/nvidia:ro \
--device /dev/nvidiactl:/dev/nvidiactl \
--device /dev/nvidia-uvm:/dev/nvidia-uvm \
--device $FIRST_GPU_DEVICE_MOUNT \
--device $SECND_GPU_DEVICE_MOUNT \
-e GPUS=${GPUS} \
-e NUM_GPU_DEVICES=2 \
-e NUM_CPU_CORES=$NUM_CPU_CORES \
-e MEMORY_GB=200 \
-e RANDOM_SEED=12345 \
-e WALLTIME_MINUTES=20160 \
--volume-driver=nvidia-docker \
$RO_VOLUME_MOUNTS \
-v ${INFERENCE_OUTPUT}/predictions.tsv:/output/predictions.tsv \
-v ${SCRATCH}:/scratch \
--log-driver="json-file" \
--log-opt max-file="2" \
--log-opt max-size="1g" \
--cpuset-cpus $CPUS \
--memory 200g \
--net=none \
$IMAGE ${ENTRY_POINT}

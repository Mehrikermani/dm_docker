#!/bin/bash
#
# This script starts the server-side agent for the Digital Mammography challenge
# It's generic with respect to evaluation queues, metadata mounts, and preprocesing
# slots so it can be invoked for the leaderboard, express lane, final validation, etc.
#

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

# The following is specific to the agent (differentiating the agents running on a host)
if [[ ${AGENT_INDEX} = 1 ]]; then
	GPUS=/dev/nvidia0,/dev/nvidia1
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
	GPUS=/dev/nvidia2,/dev/nvidia3
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
TRAINING_SCRATCH=/data/scratch${AGENT_INDEX_MINUS_1}
INFERENCE_OUTPUT=/data/inference${AGENT_INDEX_MINUS_1}

if [[ ${ROLE} = "train" ]]; then
	EVALUATION_IDS=${TRAIN_EVALUATION_IDS}
	DOCKER_VOLUME_MOUNTS="${PREPROCESSING_SLOT_MOUNTS} \
-v ${TRAINING_DATA}:/trainingData -e HOST_TRAINING_DATA=${TRAINING_DATA} \
-v ${MODEL_STATE}:/modelState -e HOST_MODEL_STATE=${MODEL_STATE} \
-v ${TRAINING_SCRATCH}:/scratch -e HOST_TRAINING_SCRATCH=${TRAINING_SCRATCH} \
-v ${TEMP_DIR}:/tempDir -e HOST_TEMP=${TEMP_DIR} \
-v /etc/docker:/certs -e DOCKER_CERT_PATH=/certs"

	ROLE_SPECIFIC_ENV="-e TRAINING_RO_VOLUMES=${TRAINING_EXAM_METADATA_MOUNT},${TRAINING_IMAGE_METADATA_MOUNT}"

elif [[ ${ROLE} = "score" ]]; then
	EVALUATION_IDS=${SCORE_EVALUATION_IDS}
	DOCKER_VOLUME_MOUNTS="-v ${SC1_SCORING_DATA}:/sc1ScoringData \
-e SC1_HOST_TESTING_DATA=${SC1_SCORING_DATA} \
-v ${SC2_SCORING_DATA}:/sc2ScoringData -e SC2_HOST_TESTING_DATA=${SC2_SCORING_DATA} \
-v ${MODEL_STATE}:/modelState -e HOST_MODEL_STATE=${MODEL_STATE} \
-v ${TRAINING_SCRATCH}:/scratch -e HOST_TRAINING_SCRATCH=${TRAINING_SCRATCH} \
-v ${INFERENCE_OUTPUT}:/output -e HOST_INFERENCE_OUTPUT=${INFERENCE_OUTPUT} \
-v ${TEMP_DIR}:/tempDir -e HOST_TEMP=${TEMP_DIR} \
-v /etc/docker:/certs -e DOCKER_CERT_PATH=/certs"

	ROLE_SPECIFIC_ENV="-e SC1_RO_VOLUMES=${SC1_SCORING_IMAGE_METADATA_MOUNT} \
-e SC2_RO_VOLUMES=${SC2_SCORING_EXAM_METADATA_MOUNT},${SC2_SCORING_IMAGE_METADATA_MOUNT}"

else
	echo "INVALID ROLE " ${ROLE}
	exit 1
fi

if [[ ${DOCKER_MACHINE_IP} = "bm01-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.154.28.49
elif [[ ${DOCKER_MACHINE_IP} = "bm02-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.154.28.56
elif [[ ${DOCKER_MACHINE_IP} = "bm03-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.154.28.53
elif [[ ${DOCKER_MACHINE_IP} = "bm04-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.154.28.44
elif [[ ${DOCKER_MACHINE_IP} = "bm05-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.154.28.59
elif [[ ${DOCKER_MACHINE_IP} = "bm06-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.154.28.38
elif [[ ${DOCKER_MACHINE_IP} = "bm07-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.154.28.47
elif [[ ${DOCKER_MACHINE_IP} = "bm08-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.154.28.43
elif [[ ${DOCKER_MACHINE_IP} = "bm09-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.154.28.39
elif [[ ${DOCKER_MACHINE_IP} = "bm10-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.154.28.61
elif [[ ${DOCKER_MACHINE_IP} = "bm11-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.155.104.107
elif [[ ${DOCKER_MACHINE_IP} = "bm12-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.155.104.112
elif [[ ${DOCKER_MACHINE_IP} = "bm13-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.155.104.68
elif [[ ${DOCKER_MACHINE_IP} = "bm14-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.155.104.101
elif [[ ${DOCKER_MACHINE_IP} = "bm15-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.155.104.86
elif [[ ${DOCKER_MACHINE_IP} = "bm16-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.155.104.71
elif [[ ${DOCKER_MACHINE_IP} = "bm17-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.155.104.87
elif [[ ${DOCKER_MACHINE_IP} = "bm18-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.155.104.119
elif [[ ${DOCKER_MACHINE_IP} = "bm19-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.155.104.97
elif [[ ${DOCKER_MACHINE_IP} = "bm20-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.155.104.114
elif [[ ${DOCKER_MACHINE_IP} = "bm21-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.155.104.82
elif [[ ${DOCKER_MACHINE_IP} = "bm22-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.155.104.69
elif [[ ${DOCKER_MACHINE_IP} = "bm23-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.155.104.108
elif [[ ${DOCKER_MACHINE_IP} = "bm24-dreamchallenge.sl851865.sl.edst.ibm.com" ]]; then
	DOCKER_MACHINE_PRIVATE_IP=10.173.140.95
elif [[ ${DOCKER_MACHINE_IP} = ec* ]]; then
	DOCKER_MACHINE_PRIVATE_IP=${DOCKER_MACHINE_IP}
else
	echo "Unexpected DOCKER_MACHINE_IP" ${DOCKER_MACHINE_IP}
	exit 1
fi


docker run -d \
-e SYNAPSE_USERNAME=${SYNAPSE_USERNAME} \
-e SYNAPSE_PASSWORD=${SYNAPSE_PASSWORD} \
-e DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME} \
-e DOCKERHUB_PASSWORD=${DOCKERHUB_PASSWORD} \
-e EVALUATION_IDS=${EVALUATION_IDS} \
-e GPUS=${GPUS} \
-e CPUS=${CPUS} \
-e NUM_GPU_DEVICES=2 \
-e NUM_CPU_CORES=${NUM_CPU_CORES} \
-e MEMORY_GB=200 \
-e EVALUATION_ROLES=${EVALUATION_ROLES} \
-e RANDOM_SEED=12345 \
${DOCKER_VOLUME_MOUNTS} \
-e DOCKER_ENGINE_URL=tcp://${DOCKER_MACHINE_IP}:2376 \
-e NVIDIA_PLUG_IN_HOST=${DOCKER_MACHINE_PRIVATE_IP}:3476 \
-e UPLOAD_PROJECT_ID=syn4224222 \
-e CONTAINER_OUTPUT_FOLDER_ENTITY_ID=syn7217450 \
-e SC1_PREDICTIONS_FOLDER_ID=syn7238736 \
-e SC2_PREDICTIONS_FOLDER_ID=syn7238747 \
-e AGENT_ENABLE_TABLE_ID=syn7211745 \
-e SERVER_SLOT_TABLE_ID=${SERVER_SLOT_TABLE_ID} \
-e IMAGE_ARCHIVE_PROJECT_ID=${IMAGE_ARCHIVE_PROJECT_ID} \
-e UPLOAD_TABLE_PARENT_PROJECT_ID=${UPLOAD_TABLE_PARENT_PROJECT_ID} \
${ROLE_SPECIFIC_ENV} \
-e HOST_ID=${DOCKER_MACHINE_NAME} \
-e ROUND_START_DATE_TIME=2017-03-28.00:00:00 \
-e ROUND_END_DATE_TIME=2017-04-26.08:00:00 \
-e HMAC_SECRET=${HMAC_SECRET} \
-e IS_EXPRESS_LANE=${IS_EXPRESS_LANE} \
-h ${DOCKER_MACHINE_NAME}-${AGENT_INDEX} \
--cpuset-cpus=${AGENT_CPUS} \
--name ${DOCKER_MACHINE_NAME}-${ROLE}-${AGENT_INDEX} brucehoff/challengedockeragent

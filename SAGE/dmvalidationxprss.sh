#!/bin/bash
#
# This script starts the validation agent for the Digital Mammography challenge
# Run from a shell which is also running Docker and Docker Machine, and 
# in which Docker Machine 'points' to the server on which to run the agent
#
#
#
# parameters are:
# role (train or score)
#
# The following are environment variables
# synapse username
# synapse password
#
ROLE=$1

DOCKER_MACHINE_NAME=$(docker-machine active)
echo DOCKER_MACHINE_NAME=${DOCKER_MACHINE_NAME}
DOCKER_MACHINE_IP=$(docker-machine ip ${DOCKER_MACHINE_NAME})
echo DOCKER_MACHINE_IP=${DOCKER_MACHINE_IP}

if [[ ${ROLE} = "train" ]]; then
	EVALUATION_IDS=7500018
elif [[ ${ROLE} = "score" ]]; then
	EVALUATION_IDS=7500022,7500024
else
	echo "INVALID ROLE " ${ROLE}
	exit 1
fi
# the following are the same for all queues
# this is a map from evaluation ID to role (train, score on sub-chall 1 or score on sub-chall 2)
# It is OK to have multiple queues that map to the same role
EVALUATION_ROLES=\{\"7500018\":\"TRAIN\",\"7500022\":\"SCORE_SC_1\",\"7500024\":\"SCORE_SC_2\"\}

docker run -d \
-e SYNAPSE_USERNAME=${SYNAPSE_USERNAME} \
-e SYNAPSE_PASSWORD=${SYNAPSE_PASSWORD} \
-e DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME} \
-e DOCKERHUB_PASSWORD=${DOCKERHUB_PASSWORD} \
-v /etc/docker:/certs -e DOCKER_CERT_PATH=/certs \
-e DOCKER_ENGINE_URL=tcp://${DOCKER_MACHINE_IP}:2376 \
-e EVALUATION_IDS=${EVALUATION_IDS} \
-e EVALUATION_ROLES=${EVALUATION_ROLES} \
--name ${ROLE}-validator-xprss brucehoff/challengedockeragent mvn "exec:java" "-DentryPoint=org.sagebionetworks.validation.SubmissionValidationAgent"


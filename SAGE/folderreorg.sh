#!/bin/bash
#
#
#
#
#
# The following are environment variables
# synapse username
# synapse password
#

DOCKER_MACHINE_NAME=$(docker-machine active)
echo DOCKER_MACHINE_NAME=${DOCKER_MACHINE_NAME}

docker run -d \
-e SYNAPSE_USERNAME=${SYNAPSE_USERNAME} \
-e SYNAPSE_PASSWORD=${SYNAPSE_PASSWORD} \
-e CONTAINER_OUTPUT_FOLDER_ENTITY_ID=syn7217450 \
--name folder-reorg brucehoff/challengedockeragent mvn "exec:java" "-DentryPoint=org.sagebionetworks.Archiver"


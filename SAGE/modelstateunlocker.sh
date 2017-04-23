#!/bin/bash
#
# This script starts the model state unlocking service for the Digital Mammography challenge
# Run from a shell which is also running Docker and Docker Machine, and 
# in which Docker Machine 'points' to the server on which to run the agent
#
#
# The following are environment variables
# synapse MODEL_STATE_UNLOCKER_SYNAPSE_USERNAME
# synapse MODEL_STATE_UNLOCKER_SYNAPSE_PASSWORD
#

docker run -d \
-e SYNAPSE_USERNAME=${MODEL_STATE_UNLOCKER_SYNAPSE_USERNAME} \
-e SYNAPSE_PASSWORD=${MODEL_STATE_UNLOCKER_SYNAPSE_PASSWORD} \
-e CONTAINER_OUTPUT_FOLDER_ENTITY_ID=syn7217450 \
-e HMAC_SECRET=${HMAC_SECRET} \
-e ROUND_START_DATE_TIME=2017-03-28.00:00:00 \
-e ROUND_END_DATE_TIME=2017-04-26.08:00:00 \
-e HMAC_SECRET=${HMAC_SECRET} \
-e UPLOAD_TABLE_PARENT_PROJECT_ID=syn7887972 \
-e EVALUATION_ID=8533480 \
--name model-state-unlocker brucehoff/challengedockeragent mvn "exec:java" "-DentryPoint=org.sagebionetworks.dataaccess.ModelStateUnlocker"


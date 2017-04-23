#!/bin/bash
#
# This is a template for the script that starts up a DM challenge agents 
# on a GPU server.  To use it:
# (1) Customize the template, following the instructions embedded below;
# 	(Look at dmagentprod.sh as an example.)
# (2) Use the script on a machine running Docker and Docker Machine;
# (3) Run 
#	'./updateAgents.sh train <your customized script>  <space-separated list of server names>
# or
#	'./updateAgents.sh score <your customized script>  <space-separated list of server names>
# for example: 
#	./updateAgents.sh score ./dmagentprod.sh p28x20 p28x26 p28x27

export ROLE=$1
export AGENT_INDEX=$2

# fill in with the 7 digit ID of the training evaluation queue the agent should monitor
export TRAIN_EVALUATION_IDS=
# fill in with the comma delimited, 7 digit ID(s) of the inference evaluation 
# queue(s) the agent should monitor
export SCORE_EVALUATION_IDS=
# this is a map from evaluation ID to role (train, score on sub-chall 1 or score on sub-chall 2)
# Fill in this map where the keys are the evaluation IDs from above and the values are the 'roles'
# of each queue.
# It is OK to have multiple queues that map to the same role, i.e. the agent can monitor multiple
# queues that server similar purposes.
export EVALUATION_ROLES=\{\"\":\"TRAIN\",\"\":\"SCORE_SC_1\",\"\":\"SCORE_SC_2\"\}
# fill in the location of the training image data
export TRAINING_DATA=
# fill in the location of the inference image data for sub-challenge 1
export SC1_SCORING_DATA=
# fill in the location of the inference image data for sub-challenge 2
export SC2_SCORING_DATA=
# fill in the location of the training clinical metadata .tsv file
export TRAINING_EXAM_METADATA_MOUNT=.../training_exams_metadata.tsv:/metadata/exams_metadata.tsv
# fill in the location of the training image metadata .tsv file
export TRAINING_IMAGE_METADATA_MOUNT=.../training_images_crosswalk.tsv:/metadata/images_crosswalk.tsv
# fill in the location of the sub-challenge 1 image metadata .tsv file
export SC1_SCORING_IMAGE_METADATA_MOUNT=.../SC1_test_images_crosswalk.tsv:/metadata/images_crosswalk.tsv
# fill in the location of the sub-challenge 2 clinical metadata .tsv file
export SC2_SCORING_EXAM_METADATA_MOUNT=.../SC2_test_exams_metadata.tsv:/metadata/exams_metadata.tsv
# fill in the location of the sub-challenge 2 image metadata .tsv file
export SC2_SCORING_IMAGE_METADATA_MOUNT=.../SC2_test_images_crosswalk.tsv:/metadata/images_crosswalk.tsv
# fill in the Synapse ID of the table managing the preprocessing data slots.  To see an example of the required
# schema for the table, see syn8533493
export SERVER_SLOT_TABLE_ID=
# Optional: Customize the Synapse project to which Docker repository tags for submitted images are pushed.
export IMAGE_ARCHIVE_PROJECT_ID=syn7887972
# Optional:  Customize the project which tracks how many bytes of data has been downloaded 
export UPLOAD_TABLE_PARENT_PROJECT_ID=syn7887972
export IS_EXPRESS_LANE=false
# fill in the preprocessing slots. Note these must match the content of the SERVER_SLOT_TABLE_ID table
export PREPROCESSING_SLOT_MOUNTS="-v /data/dataset0:/data/dataset0 \
-v /data/dataset1:/data/dataset1 \
-v /data/dataset2:/data/dataset2 \
-v /data/dataset3:/data/dataset3"

BASEDIR=$(dirname "$0")
${BASEDIR}/dmagent_core.sh

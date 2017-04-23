#!/bin/bash
#
# dm-agent-dryrun-validation.sh
#
# This script starts the server-side agent for the Digital Mammography challenge
# Run from a shell which is also running Docker and Docker Machine, and 
# in which Docker Machine 'points' to the server on which to run the agent
#
#
#
# parameters are:
# role (train or score)
# agent index (1 or 2)
#
# The following are environment variables:
# synapse username
# synapse password
# dockerhub username
# dockerhub password
#
export ROLE=$1
export AGENT_INDEX=$2

export TRAIN_EVALUATION_IDS=8450475
export SCORE_EVALUATION_IDS=8429676,8429678
export EVALUATION_ROLES=\{\"8450475\":\"TRAIN\",\"8429676\":\"SCORE_SC_1\",\"8429678\":\"SCORE_SC_2\"\}
export TRAINING_DATA=/data/data/dm-challenge-dcm/training
export SC1_SCORING_DATA=/data/data/dm-challenge-dcm/SC1_test
export SC2_SCORING_DATA=/data/data/dm-challenge-dcm/SC2_test
export TRAINING_EXAM_METADATA_MOUNT=/data/data/metadata/training_exams_metadata.tsv:/metadata/exams_metadata.tsv
export TRAINING_IMAGE_METADATA_MOUNT=/data/data/metadata/training_images_crosswalk.tsv:/metadata/images_crosswalk.tsv
export SC1_SCORING_IMAGE_METADATA_MOUNT=/data/data/metadata/SC1_test_images_crosswalk.tsv:/metadata/images_crosswalk.tsv
export SC2_SCORING_EXAM_METADATA_MOUNT=/data/data/metadata/SC2_test_exams_metadata.tsv:/metadata/exams_metadata.tsv
export SC2_SCORING_IMAGE_METADATA_MOUNT=/data/data/metadata/SC2_test_images_crosswalk.tsv:/metadata/images_crosswalk.tsv
export SERVER_SLOT_TABLE_ID=syn8450447
export IMAGE_ARCHIVE_PROJECT_ID=syn7887972
export UPLOAD_TABLE_PARENT_PROJECT_ID=syn7887972
export IS_EXPRESS_LANE=false
export PREPROCESSING_SLOT_MOUNTS="-v /data/dataset0:/data/dataset0 \
-v /data/dataset1:/data/dataset1 \
-v /data/dataset2:/data/dataset2 \
-v /data/dataset3:/data/dataset3"

BASEDIR=$(dirname "$0")
${BASEDIR}/dmagent_core.sh

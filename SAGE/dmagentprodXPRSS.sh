#!/bin/bash
#
#
# This is the set up for the 'express lane' queues
#
#
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

export TRAIN_EVALUATION_IDS=7500018
export SCORE_EVALUATION_IDS=7500022,7500024
export EVALUATION_ROLES=\{\"7500018\":\"TRAIN\",\"7500022\":\"SCORE_SC_1\",\"7500024\":\"SCORE_SC_2\"\}
export TRAINING_DATA=/data/data/images/training
export SC1_SCORING_DATA=/data/data/images/SC1_leaderboard
export SC2_SCORING_DATA=/data/data/images/SC2_leaderboard
export TRAINING_EXAM_METADATA_MOUNT=/data/data/metadata/challenge/training_exams_metadata.tsv:/metadata/exams_metadata.tsv
export TRAINING_IMAGE_METADATA_MOUNT=/data/data/metadata/challenge/training_images_crosswalk.tsv:/metadata/images_crosswalk.tsv
export SC1_SCORING_IMAGE_METADATA_MOUNT=/data/data/metadata/challenge/SC1_leaderboard_images_crosswalk.tsv:/metadata/images_crosswalk.tsv
export SC2_SCORING_EXAM_METADATA_MOUNT=/data/data/metadata/challenge/SC2_leaderboard_exams_metadata.tsv:/metadata/exams_metadata.tsv
export SC2_SCORING_IMAGE_METADATA_MOUNT=/data/data/metadata/challenge/SC2_leaderboard_images_crosswalk.tsv:/metadata/images_crosswalk.tsv
export SERVER_SLOT_TABLE_ID=syn7413559
export IMAGE_ARCHIVE_PROJECT_ID=syn7887977
export UPLOAD_TABLE_PARENT_PROJECT_ID=syn7887977
export IS_EXPRESS_LANE=true
export PREPROCESSING_SLOT_MOUNTS="-v /data/dataset0:/data/dataset0 \
-v /data/dataset1:/data/dataset1 \
-v /data/dataset2:/data/dataset2 \
-v /data/dataset3:/data/dataset3 \
-v /data/dataset4:/data/dataset4 \
-v /data/dataset5:/data/dataset5 \
-v /data/dataset6:/data/dataset6 \
-v /data/dataset7:/data/dataset7 \
-v /data/dataset8:/data/dataset8 \
-v /data/dataset9:/data/dataset9 \
-v /data/dataset10:/data/dataset10 \
-v /data/dataset11:/data/dataset11 \
-v /data/dataset12:/data/dataset12 \
-v /data/dataset13:/data/dataset13 \
-v /data/dataset14:/data/dataset14 \
-v /data/dataset15:/data/dataset15 \
-v /data/dataset16:/data/dataset16 \
-v /data/dataset17:/data/dataset17 \
-v /data/dataset18:/data/dataset18 \
-v /data/dataset19:/data/dataset19 \
-v /data/dataset20:/data/dataset20 \
-v /data/dataset21:/data/dataset21 \
-v /data/dataset22:/data/dataset22 \
-v /data/dataset23:/data/dataset23 \
-v /data/dataset24:/data/dataset24 \
-v /data/dataset25:/data/dataset25 \
-v /data/dataset26:/data/dataset26 \
-v /data/dataset27:/data/dataset27 \
-v /data/dataset28:/data/dataset28 \
-v /data/dataset29:/data/dataset29 \
-v /data/dataset30:/data/dataset30 \
-v /data/dataset31:/data/dataset31 \
-v /data/dataset32:/data/dataset32 \
-v /data/dataset33:/data/dataset33 \
-v /data/dataset34:/data/dataset34 \
-v /data/dataset35:/data/dataset35 \
-v /data/dataset36:/data/dataset36 \
-v /data/dataset37:/data/dataset37 \
-v /data/dataset38:/data/dataset38 \
-v /data/dataset39:/data/dataset39 \
-v /data/dataset40:/data/dataset40 \
-v /data/dataset41:/data/dataset41 \
-v /data/dataset42:/data/dataset42 \
-v /data/dataset43:/data/dataset43 \
-v /data/dataset44:/data/dataset44 \
-v /data/dataset45:/data/dataset45 \
-v /data/dataset46:/data/dataset46 \
-v /data/dataset47:/data/dataset47 \
-v /data/dataset48:/data/dataset48 \
-v /data/dataset49:/data/dataset49 \
-v /data/dataset50:/data/dataset50 \
-v /data/dataset51:/data/dataset51 \
-v /data/dataset52:/data/dataset52 \
-v /data/dataset53:/data/dataset53 \
-v /data/dataset54:/data/dataset54 \
-v /data/dataset55:/data/dataset55 \
-v /data/dataset56:/data/dataset56 \
-v /data/dataset57:/data/dataset57 \
-v /data/dataset58:/data/dataset58 \
-v /data/dataset59:/data/dataset59 \
-v /data/dataset60:/data/dataset60 \
-v /data/dataset61:/data/dataset61 \
-v /data/dataset62:/data/dataset62 \
-v /data/dataset63:/data/dataset63 \
-v /data/dataset64:/data/dataset64 \
-v /data/dataset65:/data/dataset65 \
-v /data/dataset66:/data/dataset66 \
-v /data/dataset67:/data/dataset67 \
-v /data/dataset68:/data/dataset68 \
-v /data/dataset69:/data/dataset69 \
-v /data/dataset70:/data/dataset70 \
-v /data/dataset71:/data/dataset71 \
-v /data/dataset72:/data/dataset72 \
-v /data/dataset73:/data/dataset73 \
-v /data/dataset74:/data/dataset74 \
-v /data/dataset75:/data/dataset75 \
-v /data/dataset76:/data/dataset76 \
-v /data/dataset77:/data/dataset77 \
-v /data/dataset78:/data/dataset78 \
-v /data/dataset79:/data/dataset79 \
-v /data/dataset80:/data/dataset80 \
-v /data/dataset81:/data/dataset81 \
-v /data/dataset82:/data/dataset82 \
-v /data/dataset83:/data/dataset83 \
-v /data/dataset84:/data/dataset84 \
-v /data/dataset85:/data/dataset85 \
-v /data/dataset86:/data/dataset86 \
-v /data/dataset87:/data/dataset87 \
-v /data/dataset88:/data/dataset88 \
-v /data/dataset89:/data/dataset89 \
-v /data/dataset90:/data/dataset90 \
-v /data/dataset91:/data/dataset91 \
-v /data/dataset92:/data/dataset92 \
-v /data/dataset93:/data/dataset93 \
-v /data/dataset94:/data/dataset94 \
-v /data/dataset95:/data/dataset95 \
-v /data/dataset96:/data/dataset96 \
-v /data/dataset97:/data/dataset97 \
-v /data/dataset98:/data/dataset98 \
-v /data/dataset99:/data/dataset99"

BASEDIR=$(dirname "$0")
${BASEDIR}/dmagent_core.sh

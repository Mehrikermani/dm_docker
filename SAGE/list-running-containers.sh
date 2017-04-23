#!/bin/sh
for m in $(docker-machine ls -q --filter STATE=Running)
do
	eval $(docker-machine env $m)
	echo '\n' $m
	docker ps  --format "{{.Names}} {{.Status}}"
done

### To set up a server and run the challenge agent, e.g. on bm08:
- set up the server
- `./setupNewServer.sh bm08`
- 'point' to the Docker Engine (daemon) on the new server
- `eval $(docker-machine env bm08)`
- start up 'agent 1' (which governs GPU0,1)
- `./dmagentprod.sh train 1`
- start up 'agent 2' (which governs GPU2,3)
- `./dmagentprod.sh train 2`





### To update the server agent on the fleet, run these four scripts
- updateTrainAgents.sh
- updateScoreAgents.sh
- updateExpressTrainAgents.sh
- updateExpressScoreAgents.sh





### Miscellaneous tips:

#### To find out what server a submission ran on:
- Visit the page showing the submissions for the queue in which the submission ran.  The root page is here:
https://www.synapse.org/#!Synapse:syn5644795/wiki/393037
and there are four sub-pages for the different queues.
- If the submission is recent, click on the submission ID column to sort, descending.
- Now use your browser search feature to find the submission ID.  Look at the value in the "WORKER_ID" column.  It has the format "bmXX-Y".  "bmXX" is the server while Y is "1" or "2", indicating which of the server agents runs the submission.


'''
Script(s) to help rerun submissions

Created on Feb 7, 2017

@author: bhoff
'''
import synapseclient
import argparse
import json
import urllib

#import urllib3.contrib.pyopenssl
#urllib3.contrib.pyopenssl.inject_into_urllib3()

# note this matches the value in dmagentprod.sh
IMAGE_ARCHIVE_PROJECT_ID = 'syn7887972'

def lookupCommit(submissionId, phase):
    page = syn.query('select id, repositoryName from dockerrepo where repositoryName=="docker.synapse.org/'+IMAGE_ARCHIVE_PROJECT_ID+'/'+submissionId+'/'+phase+'"')
    if page['totalNumberOfResults']==0:
        return None
    if page['totalNumberOfResults']!=1:
        raise Exception("Expected one result but found "+page.totalNumberofResults)
    entityId=page['results'][0]['dockerrepo.id']
    commits = syn.restGET('/entity/'+entityId+"/dockerCommit")
    if commits['totalNumberOfResults']!=1:
        raise Exception("Expected one result but found "+commits.totalNumberofResults)
    return commits['results'][0]['digest']


# look up all submissions by submitter in queue 'evaluationId'
# for each, find string annotation.   Extract the relevant string annot (based in 'paramType')
# and extract the Docker repo+digest using 'param'.  If the value matches 'value'
# then call 'lookupCommit' to find the administrative tag for the Docker image
def lookupEarlierSubmission(submitter, evaluationId, param, paramType, value):
    if param=="inference":
        x="scoring"
    else:
        x=param
    pageSize = 25
    offset = 0
    total=100
    while offset<total:
        queryString = ("select objectId, %s from evaluation_%s where SUBMITTER==\"%s\" ORDER BY createdOn DESC LIMIT %s OFFSET %s" % (paramType, evaluationId, submitter, pageSize, offset))
        urlEncodedQueryString = urllib.urlencode({'query':queryString})
        submission_query = syn.restGET("/evaluation/submission/query?"+urlEncodedQueryString)
        offset += pageSize
        total = submission_query['totalNumberOfResults']
        if len(submission_query['rows'])==0:
            continue
        id_index = submission_query['headers'].index('objectId')
        params_index = submission_query['headers'].index(paramType)
        for sub in submission_query['rows']:
            values = sub['values']
            subId = values[id_index]
            paramsString = values[params_index]
            params = json.loads(paramsString)
            if params[param]==value:
                digest = lookupCommit(subId, x)
                if digest is not None:
                    return "docker.synapse.org/"+IMAGE_ARCHIVE_PROJECT_ID+"/"+subId+"/"+x+"@"+digest
                #else:
                #    print "\t\tSubmission "+subId+" used same "+param+" but it was not archived."
    return None

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-u","--synapseUser", required=True,
                        help="Synapse user name")
    parser.add_argument("-p","--synapsePassword", required=True,
                        help="Synapse password")
    parser.add_argument("-s", "--submissionId", required=True, help="Submission ID")
    args = parser.parse_args()

    syn = synapseclient.Synapse()
    syn = synapseclient.login(args.synapseUser, args.synapsePassword,rememberMe=False)
    
    submissionId=args.submissionId
    sub=syn.getSubmission(submissionId)
    ss = syn.getSubmissionStatus(submissionId)
    
    evaluationId = sub['evaluationId']
    submitter = None
    for a in ss.annotations['stringAnnos']:
        if a['key']=='SUBMITTER':
            submitter = a['value']
            
    result = ''
            
    for a in ss.annotations['stringAnnos']:
        if a['key']=='MODEL_STATE_ENTITY_ID':
            print "\nmodel state produced by "+submissionId+" is in: "+a['value']
        for paramType in ['TRAINING_SUBMISSION_PARAMETERS', 'SCORING_SUBMISSION_PARAMETERS']:
            if a['key']==paramType:
                params = json.loads(a['value'])
                if 'model_state' in params:
                    print "\nmodel state used by "+submissionId+" is in: "+params['model_state']
                for param in ["preprocessing", "training", "inference", "scoring"]:
                    if param=="inference":
                        x="scoring"
                    else:
                        x=param
                    if param in params:
                        result += "\n"+submissionId+" has a(n) "+param+" step "+params[param]
                        digest = lookupCommit(submissionId, x)
                        if digest is None:
                            # TODO find an earlier submission using the same preprocessing
                            commit = lookupEarlierSubmission(submitter, evaluationId, param, paramType, params[param])
                            if commit is None:
                                result += "\n\tbut there is no archived "+param+" submission"
                            else:
                                result += "\n\tUse "+commit
                        else:
                            result += "\n\tUse docker.synapse.org/"+IMAGE_ARCHIVE_PROJECT_ID+"/"+submissionId+"/"+x+"@"+digest
                    else:
                        result += "\n"+submissionId+" does NOT have a(n) "+param+" step"
                        

    print '\n\n'+result
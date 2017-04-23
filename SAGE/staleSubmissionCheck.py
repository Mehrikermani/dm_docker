'''
Created on Feb 1, 2017

@author: bhoff
'''
import synapseclient
import datetime
import argparse
import pytz
from dateutil import tz
  
EVALUATION_IDS = ['7213944', '7453778', '7453793', '7500018', '7500022', '7500024', '8533480', '8533482', '8533484']
PAGE_SIZE = 50

if __name__ == '__main__':
    
    parser = argparse.ArgumentParser()
    parser.add_argument("-u","--synapseUser", required=True,
                        help="Synapse user name")
    parser.add_argument("-p","--synapsePassword", required=True,
                        help="Synapse password")
    parser.add_argument("-d", "--delta", required=True, help="Time delta (minutes)")
    args = parser.parse_args()
    AGE_LIMIT = datetime.timedelta(minutes=int(args.delta))
    syn = synapseclient.login(args.synapseUser, args.synapsePassword,rememberMe=False)
    staleSubmissions = []
    evaluations = {}
    for evalId in EVALUATION_IDS:
        now = datetime.datetime.now(pytz.timezone('GMT'))
        evaluation = syn.getEvaluation(evalId)
        evaluations[evalId] = evaluation
        offset = 0
        anyRecords=True
        while anyRecords:
            anyRecords=False
            for submission, status in syn.getSubmissionBundles(evaluation, status="EVALUATION_IN_PROGRESS", myOwn=False, limit=PAGE_SIZE, offset=offset):
                # total=page.totalNumberOfResults
                trainingLastUpdated=None
                for longAnno in status.annotations['longAnnos']:
                    if longAnno['key']=='TRAINING_LAST_UPDATED':
                        trainingLastUpdated=datetime.datetime.utcfromtimestamp(float(longAnno['value'])/1000.0)
                        trainingLastUpdated=trainingLastUpdated.replace(tzinfo=tz.tzutc())
                        break
                  
                if (now-trainingLastUpdated>AGE_LIMIT):
                    #print evalId, submission.id, trainingLastUpdated
                    staleSubmissions.append(submission)
                
                anyRecords=True
    
            offset+=PAGE_SIZE
            
    if len(staleSubmissions)>0:
        msg = "The following submissions are stale:"
        for submission in staleSubmissions:
            msg += '\nSubmission ID: '+submission.id+" in queue "+evaluations[submission.evaluationId].name
        
        raise Exception(msg)
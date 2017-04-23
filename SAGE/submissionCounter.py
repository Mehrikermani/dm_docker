'''
Created on Feb 9, 2017

@author: bhoff
'''
import synapseclient
import argparse
import synapseclient
from datetime import datetime
import argparse
import matplotlib.pyplot as plt
from os import remove
from operator import itemgetter
import urllib
import pytz
from dateutil.parser import parse
  

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-u","--synapseUser", required=True,
                        help="Synapse user name")
    parser.add_argument("-p","--synapsePassword", required=True,
                        help="Synapse password")
    parser.add_argument("-e", "--evaluationId", required=True, help="Evaluation ID")
    args = parser.parse_args()

    syn = synapseclient.Synapse()
    syn = synapseclient.login(args.synapseUser, args.synapsePassword,rememberMe=False)
    evaluationId=args.evaluationId
    
    startTimestamp = '2017-01-03 00:00'
    endTimestamp = '2017-02-08 00:00'
    startEpoch = synapseclient.utils.to_unix_epoch_time(datetime.strptime(startTimestamp, "%Y-%m-%d %H:%M"))
    endEpoch = synapseclient.utils.to_unix_epoch_time(datetime.strptime(endTimestamp, "%Y-%m-%d %H:%M"))
    pageSize = 50
    offset = 0
    total = 100000
    teamStatusMap = {}
    while offset < total:
        queryString = ("select objectId,userId,teamId,status from evaluation_%s where createdOn>=%s and createdOn<%s LIMIT %s OFFSET %s" % (evaluationId, startEpoch, endEpoch, pageSize, offset))
        urlEncodedQueryString = urllib.urlencode({'query':queryString})
        submission_query = syn.restGET("/evaluation/submission/query?"+urlEncodedQueryString)
        total = submission_query['totalNumberOfResults']
        offset += pageSize
        id_index = submission_query['headers'].index('objectId')
        user_index = submission_query['headers'].index('userId')
        team_index = submission_query['headers'].index('teamId')
        status_index = submission_query['headers'].index('status')

        for sub in submission_query['rows']:
            values = sub['values']
            submitter=values[team_index]
            if submitter==None:
                submitter=values[user_index]
            
            statusMap = teamStatusMap.get(submitter, {})
            statusCount = statusMap.get(values[status_index],0)
            statusCount = statusCount+1
            statusMap[values[status_index]] = statusCount
            teamStatusMap[submitter]=statusMap

    for teamId in teamStatusMap:
        total=0
        for status in teamStatusMap[teamId]:
            if status!='INVALID':
                total += teamStatusMap[teamId][status]
        if total>3:
            print teamId, teamStatusMap[teamId]      


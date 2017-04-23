'''
Created on Dec 30, 2016

@author: bhoff
'''
import matplotlib
matplotlib.use("Agg")

import synapseclient
from datetime import datetime
import argparse
import matplotlib.pyplot as plt
from os import remove
from os.path import isfile
from operator import itemgetter
import urllib
import pytz
from dateutil.parser import parse
from numpy import mean
import math
  
def sortDictByValueDescending(d):
    l = []
    for key in d:
        l.append((key, d[key]))
    return sorted(l, key=itemgetter(1), reverse=True)

# merge src into dst, the latter being mutable, where the values in each dict are lists
def mergeDict(src, dst):
    for key in src:
        valueList = dst.get(key, None)
        if valueList is None:
            dst[key] = src[key]
        else :
            valueList.extend(src[key])

userNameCache = {}
def findSubmitterName(syn, submitter):
    cached = userNameCache.get(submitter, None)
    if cached is not None:
        return cached
    
    try:
        team = syn.restGET('/team/'+submitter)
        result = team['name']
    except synapseclient.exceptions.SynapseHTTPError:
        try:
            userProfile = syn.getUserProfile(submitter)
            result = userProfile.get('userName')
        except:
            result = 'NA'
        
    userNameCache[submitter]=result
    return result
        
def safeIndex(alist, avalue):
    if avalue in alist:
        return alist.index(avalue)
    else:
        return -1
    
def queue_statistics(syn, evaluationId, startTimestamp, endTimestamp, imageFileName, finalState, statusMapPrefix):
    startEpoch = synapseclient.utils.to_unix_epoch_time(datetime.strptime(startTimestamp, "%Y-%m-%d %H:%M"))
    endEpoch = synapseclient.utils.to_unix_epoch_time(datetime.strptime(endTimestamp, "%Y-%m-%d %H:%M"))
    pageSize = 50
    offset = 0
    total = 100000
    submitters=set()
    submitterRuntimeDays = {}
    statusCounts={}
    canceledCount=0
    failureReasons = {}
    completedSubmissionRuntimesDays = []
    completedOrFailedRuntimesDays = []
    startLatenciesDays = []
    submittedOnDateTimes = []
    statusSubmitterMap = {}
    submitterSubmissionMap = {}
    anyData=False
    downloadedData = []
    while offset < total:
        queryString = ("select objectId,SUBMITTER,status,createdOn,TRAINING_STARTED,modifiedOn,TRAINING_LAST_UPDATED,FAILURE_REASON,STATUS_DESCRIPTION,cancelRequested,MODEL_STATE_UNLOCKED,MODEL_STATE_SIZE_BYTES from evaluation_%s where createdOn>=%s and createdOn<%s LIMIT %s OFFSET %s" % (evaluationId, startEpoch, endEpoch, pageSize, offset))
        urlEncodedQueryString = urllib.urlencode({'query':queryString})
        submission_query = syn.restGET("/evaluation/submission/query?"+urlEncodedQueryString)
        offset += pageSize
        total = submission_query['totalNumberOfResults']
        if len(submission_query['rows'])==0:
            continue
        anyData=True
        id_index = submission_query['headers'].index('objectId')
        submitter_index = submission_query['headers'].index('SUBMITTER')
        status_index = submission_query['headers'].index('status')
        createdOn_index = submission_query['headers'].index('createdOn')
        trainingStarted_index = submission_query['headers'].index('TRAINING_STARTED')
        modifiedOn_index = submission_query['headers'].index('modifiedOn')
        modelStateUnlocked_index = safeIndex(submission_query['headers'], 'MODEL_STATE_UNLOCKED')
        modelStateSizeBytes_index = safeIndex(submission_query['headers'], 'MODEL_STATE_SIZE_BYTES')
        if 'TRAINING_LAST_UPDATED' in submission_query['headers']:
            submission_last_updated_index = submission_query['headers'].index('TRAINING_LAST_UPDATED')
        else:
            submission_last_updated_index = modifiedOn_index
            
        failureReason_index = submission_query['headers'].index('FAILURE_REASON')
        cancelRequested_index = submission_query['headers'].index('cancelRequested')
        statusDescription_index = submission_query['headers'].index('STATUS_DESCRIPTION')
        
        for sub in submission_query['rows']:
            values = sub['values']
            submitter=values[submitter_index]
            status=values[status_index]
            if submitter is not None:
                submitters.add(submitter)
                submitterSet = statusSubmitterMap.get(statusMapPrefix+status, set())
                submitterSet.add(submitter)
                statusSubmitterMap[statusMapPrefix+status] = submitterSet
            statusCounts[status] = 1 + statusCounts.get(status, 0)
            if values[cancelRequested_index]=='true':
                canceledCount += 1
            if status!=finalState and status!="EVALUATION_IN_PROGRESS"and status!="OPEN":
                failureReason = values[failureReason_index]
                if failureReason is None and values[cancelRequested_index]=='true':
                    failureReason = 'Canceled Upon Request'
                failureReasons[failureReason] = 1 + failureReasons.get(failureReason, 0)
            createdOn = int(values[createdOn_index])
            trainingStartedString = values[trainingStarted_index]
            if values[submission_last_updated_index] is None:
                submission_last_updated = int(values[modifiedOn_index])
            else:
                submission_last_updated = int(values[submission_last_updated_index])
            # Note:  trainingStarted is missing if the submission was invalid or canceled before it began
            if trainingStartedString is not None:
                trainingStarted = int(trainingStartedString)
                runTimeMillis = submission_last_updated - trainingStarted
                startLatencyDays = float(trainingStarted - createdOn)/3600000./24.
                startLatenciesDays.append(startLatencyDays)
                submittedOnDateTimes.append(synapseclient.utils.from_unix_epoch_time(createdOn))
                if status==finalState:
                    completedSubmissionRuntimesDays.append(float(runTimeMillis)/3600000./24.)
                if status==finalState or status=='CLOSED' or status=='INVALID':
                    completedOrFailedRuntimesDays.append(float(runTimeMillis)/3600000./24.)
                submitterRuntimeDays[submitter] = float(runTimeMillis)/3600000./24. + float(submitterRuntimeDays.get(values[submitter_index], 0))
                
                summary={"submitter":submitter, 
                         "createdOn":synapseclient.utils.from_unix_epoch_time(createdOn),
                         "startedOn":synapseclient.utils.from_unix_epoch_time(trainingStarted),
                         "lastUpdatedOn":synapseclient.utils.from_unix_epoch_time(submission_last_updated),
                         "status":status}
                submitterList = submitterSubmissionMap.get(submitter, [])
                submitterList.append(summary)
                submitterSubmissionMap[submitter] = submitterList
                
            if modelStateUnlocked_index>=0 and modelStateSizeBytes_index>=0 and values[modelStateUnlocked_index] is not None:
                downloadedData.append((submitter, trainingStarted, int(values[modelStateSizeBytes_index])))

    num_bins = 100
    
    wikiSection = submissionQueueTemplate()

#     fig, axes = plt.subplots(nrows=4, ncols=1)
#     fig.tight_layout()
#     plt.subplots_adjust(hspace=0.5) #0.4 is too little, 3 is  too much
    if anyData and imageFileName is not None:
        if len(completedSubmissionRuntimesDays)>0:
            plt.figure(figsize=(9,11))
            plt.subplot(411)
            plt.hist(completedSubmissionRuntimesDays, num_bins, facecolor='green')
            plt.yscale('log', nonposy='clip')
            plt.ylim(ymin=0.1)
            plt.ylabel('Submission Count')
            plt.title('Run times for completed submissions, days. n='+str(len(completedSubmissionRuntimesDays))+" mean="+str(round(mean(completedSubmissionRuntimesDays),2))+".")
            plt.subplots_adjust(left=0.15)
            
        if len(submitterRuntimeDays)>0:
            plt.subplot(412)
            plt.hist(submitterRuntimeDays.values(), num_bins, facecolor='green')
            plt.ylabel('Team Count')
            plt.title('Cumulative submission run time per team, days. n='+str(len(submitterRuntimeDays)))
    
        if len(startLatenciesDays)>0:
            plt.subplot(413)
            plt.hist(startLatenciesDays, num_bins, facecolor='green')
            plt.ylabel('Submission Count')
            plt.yscale('log', nonposy='clip')
            plt.ylim(ymin=0.1)
            plt.title('Start latencies for submissions, days. n='+str(len(startLatenciesDays)))
            
            plt.subplot(414)
            plt.plot(submittedOnDateTimes, startLatenciesDays, 'bo')
            plt.yscale('log')
            plt.ylabel('Start Latency, days')
            plt.title('Start latencies as a function of submission date. n='+str(len(startLatenciesDays)))
        
        plt.savefig(imageFileName)
        plt.clf()
    
        wikiSection = wikiSection.replace("**imageFileName**", imageFileName)
            
        cycleTime="Average time to terminate (successfully or failing): "+str(round(mean(completedOrFailedRuntimesDays),2))+" days."
        wikiSection = wikiSection.replace("**cycleTime**", cycleTime)

            
        evaluation = syn.getEvaluation(evaluationId)
        
        wikiSection = wikiSection.replace("**title**", evaluation.name)
        wikiSection = wikiSection.replace("**submissionCount**", str(total))
        wikiSection = wikiSection.replace("**teamCount**", str(len(submitters)))
        if finalState in statusCounts:
            completedSubmissionCount=str(statusCounts[finalState])
        else:
            completedSubmissionCount='NONE'
        wikiSection = wikiSection.replace("**completedSubmissionCount**", completedSubmissionCount)
        if 'INVALID' in statusCounts:
            invalidCount=str(statusCounts['INVALID'])
        else:
            invalidCount='NONE'
        wikiSection = wikiSection.replace("**invalidCount**",  invalidCount)
        
        statusTable = 'Status|Count\n---|---'
        for status in statusCounts:
            if status==finalState:
                statusLabel = status+' (completed state)'
            else :
                statusLabel = status
            count = str(statusCounts[status])
            if status=='CLOSED' and canceledCount>0:
                count = count+' (# canceled='+str(canceledCount)+')'
            statusTable = statusTable + '\n'+statusLabel+'|'+count
        
        wikiSection = wikiSection.replace("**statusCountTable**", statusTable)
        
        
        activeTeams = 'Team|Cumulative Days\n---|---'
        topTeams = sortDictByValueDescending(submitterRuntimeDays)
        num_rows=3
        for i in range(len(topTeams)):
            if i>num_rows:
                break
            activeTeams = activeTeams + '\n'+findSubmitterName(syn,topTeams[i][0])+'|'+str(topTeams[i][1])
        if len(topTeams) > num_rows:
            activeTeams = activeTeams + '\n...|...'
        wikiSection = wikiSection.replace("**activeTeamsTable**", activeTeams)
        
        failureReasonsTable = 'Failure Reason|Count\n---|---'
        topFailures = sortDictByValueDescending(failureReasons)
        num_rows = 15
        for i in range(len(topFailures)):
            if i>num_rows:
                break
            topFailureLabel = topFailures[i][0]
            if topFailureLabel is None:
                topFailureLabel = "No reason given"
            else:
                topFailureLabel = topFailureLabel.strip().replace('\n', ' ').replace('\r', ' ')
            failureReasonsTable = failureReasonsTable + '\n'+topFailureLabel+'|'+str(topFailures[i][1])
        if len(topFailures) > num_rows:
            failureReasonsTable = failureReasonsTable + '\n...|...'
        wikiSection = wikiSection.replace("**failureReasonsTable**", failureReasonsTable)
    

    
    return wikiSection, statusSubmitterMap, submitterSubmissionMap, downloadedData

def wikiTemplate():
    return """
## Digital Mammography Challenge Participant Statistics

**trainingSubmissions**

**dataDownload**

**subChall1Submissions**
    
**subChall2Submissions**


&nbsp;
#### Comparisons of Team Activity across Submission Queues

&nbsp;
&nbsp;
This table compares the activity of teams in training and scoring for the leaderboard.  Each value is the number of teams that submitted *both* a submission that reached the state in the training queue indicated by the value's row *and also* the state in the inference queue indicated by the value's column.
**trainToInferenceComparisonTable**

&nbsp;
This table compares activity of teams in *training* on the express lane and in the leaderboard:
**trainELtoLBComparisonTable**

&nbsp;
This table compares activity of teams in *inference* on the express lane and in the leaderboard:
**inferenceELtoLBComparisonTable**

This wiki was created by: https://github.com/Sage-Bionetworks/DigitalMammographyChallenge/blob/master/round_statistics.py
    """
    
def submissionQueueTemplate():
    return """
#### **title**
There were **submissionCount** submissions from **teamCount** distinct teams.  **completedSubmissionCount** ran to completion.  The counts for each submission state are shown in this table:

**statusCountTable**

${image?fileName=**imageFileName**&responsive=false}
&nbsp;
**cycleTime**

&nbsp;
The most active teams were:
**activeTeamsTable**


Of the submissions which did not complete, the reasons given were:
**failureReasonsTable**

    """

def dataDownloadWikiTemplate():
    return """
#### Data download

${image?fileName=**dataDownloadFileName**&responsive=false}
&nbsp;

    """

# downloadedData is a list of triples (submitter, time stamp (as a unix epoch, msec), model state size (in bytes))
def data_download(downloadedData, globalLogDownloadRecords, startTimestamp, endTimestamp, syn, dataDownloadFileName):

    startTimeStampAsEpoch = synapseclient.utils.to_unix_epoch_time(parse(startTimestamp))
    endTimeStampAsEpoch = synapseclient.utils.to_unix_epoch_time(parse(endTimestamp))
    modelStateAndLogData = list(downloadedData)
    for elem in globalLogDownloadRecords:
        epoch = elem[1]
        if epoch>=startTimeStampAsEpoch and epoch<endTimeStampAsEpoch:
            modelStateAndLogData.append(elem)
    
    print"\n\nNumber of downloaded model-state files: "+str(len(downloadedData))+\
        " number of downloaded log files "+str(len(modelStateAndLogData)-len(downloadedData))+"\n\n"
        
    if len(modelStateAndLogData)==0:
        return ''
    
    result = dataDownloadWikiTemplate()
    result = result.replace('**dataDownloadFileName**', dataDownloadFileName)
    sortedDownloadedData = sorted(modelStateAndLogData, key = lambda entry: entry[1])
    allTimestamps = [parse(startTimestamp+" GMT")]
    bytesPerGigaByte = math.pow(2,30)
    allModelStates = [0]
    submitterDataMap = {}
    for entry in sortedDownloadedData:
        submitter = entry[0]
        timestamp = synapseclient.utils.from_unix_epoch_time(entry[1])
        sizeGB = float(entry[2])/bytesPerGigaByte
        
        allTimestamps.append(timestamp)
        allModelStates.append(allModelStates[-1]+sizeGB)
        
        submitterData = submitterDataMap.get(submitter, None)
        if submitterData is None:
            submitterData = ([parse(startTimestamp+" GMT")], [0])
            submitterDataMap[submitter]=submitterData
        submitterData[0].append(timestamp)
        submitterData[1].append(submitterData[1][-1]+sizeGB)
        
    plt.clf()
    plt.figure(figsize=(10, 10))
    plt.plot(allTimestamps, allModelStates)
    plt.text(allTimestamps[-1], allModelStates[-1], 'total', fontsize=8)
    submitterText = []
    for submitter in submitterDataMap:
        submitterData = submitterDataMap[submitter]
        plt.plot(submitterData[0], submitterData[1])
        submitterName = findSubmitterName(syn, submitter)
        submitterText.append((submitterData[0][-1], submitterData[1][-1], submitterName))
 
    # sort by y value
    sortedSubmitterText = sorted(submitterText,  key = lambda entry: entry[1], reverse=True)
    
    # just plot the first ten.  All the others get mushed together
    for i in range(0, min(10, len(sortedSubmitterText))):
        plt.text(sortedSubmitterText[i][0], sortedSubmitterText[i][1], sortedSubmitterText[i][2], fontsize=8)
    
    plt.title("Downloaded Model State, GB")
    plt.savefig(dataDownloadFileName)
    plt.clf()
    
    return result

def create_page_for_round(startTimestamp, endTimestamp, wikiPageId, syn, globalLogDownloadRecords,
                        trainingEvaluationId, sc1EvaluationId, sc2EvaluationId):
    trainingFileName='training.png'
    subchall1FileName="subchall1.png"
    subchall2FileName="subchall2.png"
    dataDownloadFileName = "dataDownload.png"

    wikiMarkdown = wikiTemplate()
    
    trainingSection, trainingStatusSubmitterMap, trainingSubmitterSubmissionMap, downloadedData = queue_statistics(syn, trainingEvaluationId, startTimestamp, endTimestamp, trainingFileName, 'ACCEPTED', 'TRAIN-')
    wikiMarkdown = wikiMarkdown.replace("**trainingSubmissions**", trainingSection)
    
    subChall1Section, sc1StatusSubmitterMap, sc1SubmitterSubmissionMap, na = queue_statistics(syn, sc1EvaluationId, startTimestamp, endTimestamp, subchall1FileName, 'SCORED', 'SC1-')
    wikiMarkdown = wikiMarkdown.replace("**subChall1Submissions**", subChall1Section)
    
    subChall2Section, sc2StatusSubmitterMap, sc2SubmitterSubmissionMap, na = queue_statistics(syn, sc2EvaluationId, startTimestamp, endTimestamp, subchall2FileName, 'SCORED', 'SC2-')
    wikiMarkdown = wikiMarkdown.replace("**subChall2Submissions**", subChall2Section)
    
    
    elTrainingSection, elTrainingStatusSubmitterMap, elTrainingSubmitterSubmissionMap, na = queue_statistics(syn, "7500018", startTimestamp, endTimestamp, None, 'ACCEPTED', 'EXPRESS-LANE-TRAIN-')
    elSubChall1Section, elSc1StatusSubmitterMap, elSc1SubmitterSubmissionMap, na = queue_statistics(syn, "7500022", startTimestamp, endTimestamp, None, 'SCORED', 'EXPRESS-LANE-SC1-')
    elSubChall2Section, elSc2StatusSubmitterMap, elSc2SubmitterSubmissionMap, na = queue_statistics(syn, "7500024", startTimestamp, endTimestamp, None, 'SCORED', 'EXPRESS-LANE-SC2-')
    

    lbInferenceMaps = sc1StatusSubmitterMap.copy()
    lbInferenceMaps.update(sc2StatusSubmitterMap)
    tbl = setComparisonTable(trainingStatusSubmitterMap, lbInferenceMaps)
    wikiMarkdown = wikiMarkdown.replace("**trainToInferenceComparisonTable**", tbl)
    
    tbl = setComparisonTable(elTrainingStatusSubmitterMap, trainingStatusSubmitterMap)
    wikiMarkdown = wikiMarkdown.replace("**trainELtoLBComparisonTable**", tbl)
   
    elInferenceMaps = elSc1StatusSubmitterMap.copy()
    elInferenceMaps.update(elSc2StatusSubmitterMap)
    tbl = setComparisonTable(elInferenceMaps, lbInferenceMaps)
    wikiMarkdown = wikiMarkdown.replace("**inferenceELtoLBComparisonTable**", tbl)
    
    dataDownloadSection = data_download(downloadedData, globalLogDownloadRecords, startTimestamp, endTimestamp, syn, dataDownloadFileName)
    wikiMarkdown = wikiMarkdown.replace("**dataDownload**", dataDownloadSection)

    
    wiki = syn.getWiki("syn7986624", wikiPageId)
    wiki.markdown = wikiMarkdown
    wiki.attachments = []
    if isfile(trainingFileName):
        wiki.attachments.append(trainingFileName)
    if isfile(subchall1FileName):
        wiki.attachments.append(subchall1FileName)
    if isfile(subchall2FileName):
        wiki.attachments.append(subchall2FileName)
    if isfile(dataDownloadFileName):
        wiki.attachments.append(dataDownloadFileName)
    syn.store(wiki)
    
    if isfile(trainingFileName):
        remove(trainingFileName)
    if isfile(subchall1FileName):
        remove(subchall1FileName)
    if isfile(subchall2FileName):
        remove(subchall2FileName)        
    if isfile(dataDownloadFileName):
        remove(dataDownloadFileName)        
        
    # now make the timelines
    submitterSubmissionMap = {}
    addQueue(trainingSubmitterSubmissionMap, "training")
    mergeDict(trainingSubmitterSubmissionMap, submitterSubmissionMap)
    
    addQueue(sc1SubmitterSubmissionMap, "sc1")
    mergeDict(sc1SubmitterSubmissionMap, submitterSubmissionMap)
    
    addQueue(sc2SubmitterSubmissionMap, "sc2")
    mergeDict(sc2SubmitterSubmissionMap, submitterSubmissionMap)
    
    addQueue(elTrainingSubmitterSubmissionMap, "elTrain")
    mergeDict(elTrainingSubmitterSubmissionMap, submitterSubmissionMap)
    
    addQueue(elSc1SubmitterSubmissionMap, "elSc1")
    mergeDict(elSc1SubmitterSubmissionMap, submitterSubmissionMap)
    
    addQueue(elSc2SubmitterSubmissionMap, "elSc2")
    mergeDict(elSc2SubmitterSubmissionMap, submitterSubmissionMap)
    
    return(submitterSubmissionMap)
    
def addQueue(listMap, queue):
    for key in listMap:
        for m in listMap[key]:
            m["queue"]=queue
    
def timelineTemplate():
    return """

This plot shows the time history of submissions to the express lane, training queue and inference queue, one row per team.  The queues are color-coded lines, starting at the time of submission and ending when the submission terminated. (The time at which the submission started running is marked with a black circle.) The outcome of each submission, successful or not, is a color-coded circle.  The legend for the color codes is shown below, followed by a "20,000 ft. view" of the plot and, finally, the detailed version. The teams are ordered by the date of their most recent activity.  The first to abandon the challenge would be at the top, while recently active participants would be at the bottom.
&nbsp;
### Legend
${image?fileName=**legendFileName**&responsive=false}
### Small Size
${image?fileName=**imageFileName**&responsive=true}
### Full Size
${image?fileName=**imageFileName**&responsive=false}

    """

# http://matplotlib.org/api/colors_api.html 
QUEUE_COLORS=[('elTrain', 'b'), ('elSc1','orange'), ('elSc2','orange'), ('training', 'k'), ('sc1', 'purple'), ('sc2', 'purple')]
STATUS_COLORS=[('EVALUATION_IN_PROGRESS', 'go'), ('VALIDATED', 'go'), ('OPEN', 'go'), ('ACCEPTED', 'go'), ('SCORED', 'go'), ('INVALID', 'ro'), ('CLOSED', 'ro')]

def findLastUpdated(submissions):
    result = None
    for submission in submissions:
        latest = submission["lastUpdatedOn"]
        if result is None or latest>result:
            result = latest
    return result

def createParticipantTimelines(submitterSubmissionMap, wikiPageId):
    QUEUE_COLOR_MAP={}
    for elem in QUEUE_COLORS:
        QUEUE_COLOR_MAP[elem[0]]=elem[1]
    STATUS_COLOR_MAP = {}
    for elem in STATUS_COLORS:
        STATUS_COLOR_MAP[elem[0]]=elem[1]
    
    wikiMarkdown = timelineTemplate()
    imageFileName="participantTimeline.png"
    wikiMarkdown = wikiMarkdown.replace("**imageFileName**", imageFileName)
    plt.clf()
    plt.figure(figsize=(30, 25))
    #plt.rcParams["figure.figsize"] = (40, 8.5)
    
    submitterSubmissionList = []
    for submitter in submitterSubmissionMap:
        lastUpdated = findLastUpdated(submitterSubmissionMap[submitter])
        submitterSubmissionList.append((submitter, submitterSubmissionMap[submitter], lastUpdated))
        
    sortedList = sorted(submitterSubmissionList, key = lambda entry: entry[2], reverse=True)
    
    counter=0.5
    ticks = []
    submitterNames = []
    for entry in sortedList:
        ticks.append(counter)
        submitter = entry[0]
        submissions = entry[1]
        submitterNames.append(findSubmitterName(syn, submitter))
        for submission in submissions:
            queue = submission['queue']                
            plt.plot([submission["createdOn"], submission["lastUpdatedOn"]], [counter]*2, QUEUE_COLOR_MAP[queue], linewidth=1.0)
            plt.plot(submission["startedOn"], counter, 'ko', markersize=2.0) 
            plt.plot(submission["lastUpdatedOn"], counter, STATUS_COLOR_MAP[submission['status']], markersize=3.0) 
        counter=counter+1
        
    plt.yticks(ticks)
    ax = plt.gca()
    ax.set_yticklabels(submitterNames, size='xx-small')
    ax.grid(True)

    plt.savefig(imageFileName)
    plt.clf()
    
    # legend
    legendFileName = "legend.png"
    plt.figure(figsize=(6,4))
    plt.subplot(131)
    counter=-0.5
    ticks = []
    labels = []
    for elem in QUEUE_COLORS:
        ticks.append(counter)
        labels.append(elem[0])
        plt.plot([0,1], [counter]*2, elem[1])
        counter=counter-1
        
    plt.yticks(ticks)
    ax = plt.gca()
    ax.set_xticklabels(['']*len(ax.get_xticklabels())) # remove x labels
    ax.set_yticklabels(labels, size='xx-small')
    
    plt.subplot(133)
    counter=-0.5
    ticks = []
    labels = []
    for elem in STATUS_COLORS:
        ticks.append(counter)
        labels.append(elem[0])
        plt.plot(1, counter, elem[1], markersize=10.0)
        counter=counter-1
        
    ticks.append(counter)
    labels.append("started")
    plt.plot(1, counter, 'ko', markersize=5.0)
        
    plt.yticks(ticks)
    ax = plt.gca()
    ax.set_xticklabels(['']*len(ax.get_xticklabels())) # remove x labels
    ax.set_yticklabels(labels, size='x-small')

    plt.subplots_adjust(left=0.25)
    plt.savefig(legendFileName)
    plt.clf()
    
    wikiMarkdown = wikiMarkdown.replace("**legendFileName**", legendFileName)
    
    wiki = syn.getWiki("syn7986624", wikiPageId)
    wiki.markdown = wikiMarkdown
    wiki.attachments = []
    if isfile(imageFileName):
        wiki.attachments.append(imageFileName)
    if isfile(legendFileName):
        wiki.attachments.append(legendFileName)

    syn.store(wiki)
    
    if isfile(imageFileName):
        remove(imageFileName)
    if isfile(legendFileName):
        remove(legendFileName)
    

def setComparisonTable(rowSets, colSets):
    tbl = "|total"
    endOfHeader = "---|---"
    for scoreStatus in colSets:
        tbl += "|"+scoreStatus
        endOfHeader += "|---"
    tbl+="|none"
    endOfHeader += "|---"
    tbl += "\n"+endOfHeader
    for trainStatus in rowSets:
        tbl += "\n"+trainStatus+"|"+str(len(rowSets[trainStatus]))
        colSetUnion = set()
        for scoreStatus in colSets:
            tbl += "|"+str(len(set.intersection(rowSets[trainStatus], colSets[scoreStatus])))
            colSetUnion |= colSets[scoreStatus]
        tbl+="|"+str(len(rowSets[trainStatus].difference(colSetUnion)))
    return tbl

def getLogFileDownloadRecords(syn):
    parentId="syn7887972"
    
    result = []
    
    pageSize = 50
    offset = 1
    total = 100000
    while offset <= total:
        queryResult = syn.query("select id, name from table where parentId==\""+parentId+"\" limit "+str(pageSize)+" offset "+str(offset))
        total = int(queryResult['totalNumberOfResults'])
        offset += pageSize
        for row in queryResult['results']:
            print "name: "+row['table.name']+" id: "+row['table.id']
            table = syn.tableQuery("select * from "+row['table.id'])
            submitterIndex = -1
            uploadedIndex = -1
            sizeIndex = -1
            cntr=0
            for header in table.headers:
                if header['name']=='submitterId':
                    submitterIndex = cntr
                elif header['name']=='uploadedOn':
                    uploadedIndex = cntr
                elif header['name']=='fileSize':
                    sizeIndex = cntr
                cntr += 1
            if submitterIndex<0:
                raise "Cannot find submitterId column"
            if uploadedIndex<0:
                raise "Cannot find uploadedIndex column"
            if sizeIndex<0:
                raise "Cannot find sizeIndex column"
            for row in table:
                result.append((str(row[submitterIndex]), synapseclient.utils.to_unix_epoch_time(row[uploadedIndex]), row[sizeIndex]))
    
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-u","--synapseUser", required=True,
                        help="Synapse user name")
    parser.add_argument("-p","--synapsePassword", required=True,
                        help="Synapse password")
    args = parser.parse_args()
    syn = synapseclient.login(args.synapseUser, args.synapsePassword,rememberMe=False)
    
    round1StartTimestamp="2016-11-19 00:00" 
    round2StartTimestamp = "2017-01-02 00:00" 
    round3StartTimestamp = "2017-02-13 00:00"
    finalStartTimestamp = "2017-03-27 00:00"
    finalEndTimestamp = "2017-04-30 00:00"
    round1WikiPageId = "411307"
    round2WikiPageId = "411309"
    round3WikiPageId = "411310"
    finalWikiPageId = "411311"
    timelineWikiPageId = "415156"
    
    logDownloadRecords = getLogFileDownloadRecords(syn)
    
    print('\n\nFound a total of '+str(len(logDownloadRecords))+" log file download records.")
    
    submitterSubmissionMap = {}
    
    trainingEvaluationId = "7213944"
    sc1EvaluationId = "7453778"
    sc2EvaluationId = "7453793"
    validationTrainingEvaluationId = "8533480"
    validationSc1EvaluationId = "8533482"
    validationSc2EvaluationId = "8533484"

    now= datetime.now(pytz.timezone('GMT'))
    if now>parse(round1StartTimestamp+" GMT"):
        mergeDict(create_page_for_round(round1StartTimestamp, round2StartTimestamp, 
                                        round1WikiPageId, syn, logDownloadRecords, trainingEvaluationId, sc1EvaluationId, sc2EvaluationId), submitterSubmissionMap)
    if now>parse(round2StartTimestamp+" GMT"):
        mergeDict(create_page_for_round(round2StartTimestamp, round3StartTimestamp, 
                                        round2WikiPageId, syn, logDownloadRecords, trainingEvaluationId, sc1EvaluationId, sc2EvaluationId), submitterSubmissionMap)
    if now>parse(round3StartTimestamp+" GMT"):
        mergeDict(create_page_for_round(round3StartTimestamp, finalStartTimestamp, 
                                        round3WikiPageId, syn, logDownloadRecords, trainingEvaluationId, sc1EvaluationId, sc2EvaluationId), submitterSubmissionMap)
    if now>parse(finalStartTimestamp+" GMT"):
        mergeDict(create_page_for_round(finalStartTimestamp, finalEndTimestamp, 
                                        finalWikiPageId, syn, logDownloadRecords, validationTrainingEvaluationId, validationSc1EvaluationId, validationSc2EvaluationId), submitterSubmissionMap)
      
    createParticipantTimelines(submitterSubmissionMap, timelineWikiPageId)
    
#!/usr/bin/env python
import datetime
import time
import sys
import os
import re
def convertDate2Time(date):
    dt = datetime.datetime.strptime(date,'%Y-%m-%d %H:%M:%S')
    sec = time.mktime(dt.timetuple())
    #hr = sec/3600.0
    return sec

#2015-05-25 10:42:27,871 - fc_run - INFO - submitting /home/yunfeiguo/projects/PacBio_reference_genome/falcon_aln/hx1_20150525/0-rawreads/job_c8a222c9/rj_c8a222c9.sh for SGE, start job: d_c8a222c9_raw_reads-b9313a1e
#2015-05-25 12:05:22,839 - fc_run - INFO - /home/yunfeiguo/projects/PacBio_reference_genome/falcon_aln/hx1_20150525/0-rawreads/job_1d6ea50d/job_1d6ea50d_done generated. job: d_1d6ea50d_raw_reads-003ee38a finished.
if len(sys.argv) < 2:
    sys.exit('Usage: %s <fc_run.log>' % sys.argv[0])
file = sys.argv[1]
	
fh = open(file,'r')
job = {}
for line in fh:
    f = line.split()
    f[1] = re.sub(r',.*$',"",f[1]) #remove trailing comma
    if 'not finished' in line:
	continue
    elif 'start job' in line:
	id = f[-1]
	startDate = f[0]+' '+f[1]
    	job[id] = {'start':convertDate2Time(startDate)}
    elif 'finished' in line:
	id = f[-2]
	endDate = f[0]+' '+f[1]
	job[id]['end'] = convertDate2Time(endDate)
	    
fh.close()
stats = {
	'totalTime':0,
	'mTime':0, #jobs beginning with m_
	'ctTime':0, #ct_
	'dTime':0, #d_
	'totalCount':0,
	'mCount':0,
	'ctCount':0,
	'dCount':0,
	'unfinishedCount':0,
	}
total = 0

for i in job:
    if 'end' in job[i] and 'start' in job[i]:
	duration = job[i]['end']-job[i]['start']
    	stats['totalTime'] += duration
	stats['totalCount'] += 1
	if i.startswith('m_'):
	    stats['mTime'] += duration
	    stats['mCount'] += 1
	elif i.startswith('ct_'):
	    stats['ctTime'] += duration
	    stats['ctCount'] += 1
	elif i.startswith('d_'):
	    stats['dTime'] += duration
	    stats['dCount'] += 1
    elif 'start' in job[i]:
	stats['unfinishedCount'] += 1

stats['totalTime'] /= 3600.0
stats['mTime'] /= 3600.0
stats['ctTime'] /= 3600.0
stats['dTime'] /= 3600.0
print "Total running time (hr): ",stats['totalTime']
print "Total jobs: ",stats['totalCount']
if stats['totalCount'] != 0:
    print "Average job running time (hr):",stats['totalTime']/stats['totalCount']

print "Total d_* jobs running time (hr): ",stats['dTime']
print "Total d_* jobs: ",stats['dCount']
if stats['dCount'] != 0:
    print "Average d_* job running time (hr):",stats['dTime']/stats['dCount'] 

print "Total ct_* jobs running time (hr): ",stats['ctTime']
print "Total ct_* jobs: ",stats['ctCount']
if stats['ctCount'] != 0:
    print "Average ct_* job running time (hr):",stats['ctTime']/stats['ctCount'] 

print "Total m_* jobs running time (hr): ",stats['mTime']
print "Total m_* jobs: ",stats['mCount']
if stats['mCount'] != 0:
    print "Average m_* job running time (hr):",stats['mTime']/stats['mCount'] 

print "\n"
print "Unfinished jobs: ",stats['unfinishedCount']

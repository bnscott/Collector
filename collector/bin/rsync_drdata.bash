#!/bin/bash
#
# rsync_drdata.bash:
# bash script to rsync the DR data to Sterling Forest
#
# V1 - 2021-07-07 - Bret Scott
# V2 - 2021-09-29 - Bret Scott -- changed rsync options to omit the --perms; added step after rsync to ssh to remote and chmod go+r to the /drdata location
# 
#
##
set -a
##
HOSTNAME=$(hostname -s | sed -e 's/\(.*\)/\L\1/')
COLLECTOR_USER=drutladm
LOCAL_COLLECTOR_DIR="$(getent passwd ${COLLECTOR_USER} | cut -d: -f6 )/collector"
COLLECTOR_ENDPOINTS=${LOCAL_COLLECTOR_DIR}/collector_endpoints.in
DAYS_TO_KEEP=120
TODAY=$(date '+%Y%m%d')
WORKING_DIR=/drdata

# Redirect STDOUT & STDERR to logfile 
[[ -d ${LOCAL_COLLECTOR_DIR}/log ]] || mkdir -p ${LOCAL_COLLECTOR_DIR}/log
exec > ${LOCAL_COLLECTOR_DIR}/log/rsync_drdata-${TODAY}.log 2>&1 

case ${HOSTNAME} in
        b3vprdruinf01)  SECURITY_ZONE=INT
                        STF_UTILITY_SERVER=sfvprdruinf01
                        ;;

        b3vprdruinf02)  SECURITY_ZONE=PII
                        STF_UTILITY_SERVER=sfvprdruinf02
                        ;;

        b3vprdruinf03)  SECURITY_ZONE=DMZ
                        STF_UTILITY_SERVER=sfvprdruinf03
                        ;;

        *)              echo -e "\n ERROR:: ${0} cannot run on ${HOSTNAME}.  Exiting"
                        ;;

esac


# Rsync the $WORKING_DIR
RSYNC=/usr/bin/rsync

# Verbosity options using the --info module
#Use OPT or OPT1 for level 1 output, OPT2 for level 2, etc.; OPT0 silences.
#
#BACKUP     Mention files backed up
#COPY       Mention files copied locally on the receiving side
#DEL        Mention deletions on the receiving side
#FLIST      Mention file-list receiving/sending (levels 1-2)
#MISC       Mention miscellaneous information (levels 1-2)
#MOUNT      Mention mounts that were found or skipped
#NAME       Mention 1) updated file/dir names, 2) unchanged names
#PROGRESS   Mention 1) per-file progress or 2) total transfer progress
#REMOVE     Mention files removed on the sending side
#SKIP       Mention files that are skipped due to options used
#STATS      Mention statistics at end of run (levels 1-3)
#SYMSAFE    Mention symlinks that are unsafe
#
#ALL        Set all --info options (e.g. all4)
#NONE       Silence all --info options (same as all0)

INFO="NAME2,MISC2,FLIST2,SKIP,STATS2,DEL,SYMSAFE"

# Set the SSH options here
# ConnectionAttempts try this many times to make a connection to the ssh server
# ServerAliveInterval send ssh Alive probes to the server every XX seconds to ensure the server on the other end of the tunnel is responsive.
# ServerAliveCountMax allow this many un-answered ssh Alive probes before it considers the ssh tunnel dead and closes the connection.

SSH="ssh -o ConnectionAttempts=4 -o ServerAliveInterval=15 -o ServerAliveCountMax=8 "

${RSYNC} --rsh="${SSH}" \
 --info=${INFO} \
 --verbose \
 --recursive \
 --links \
 --times \
 --rsync-path=${RSYNC} \
 --delete \
 ${WORKING_DIR}/ ${STF_UTILITY_SERVER}:${WORKING_DIR}/ 

${SSH} ${STF_UTILITY_SERVER} chmod -R go+r ${WORKING_DIR}

## CLeanup any collector files that are older than DAYS_TO_KEEP
echo -e "\n\n++Cleaning up the following rsync logfiles..."
find ${LOCAL_COLLECTOR_DIR}/log -name "rsync_drdata*.log" -mtime +${DAYS_TO_KEEP} -print
find ${LOCAL_COLLECTOR_DIR}/log -name "rsync_drdata*.log" -mtime +${DAYS_TO_KEEP} -exec rm {} \;
##
exit 0

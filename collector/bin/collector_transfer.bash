#!/bin/bash
#
# collector_transfer.bash:
# ksh script to transfer the collector output files to the STF utilty server
#
# V1 - 2021-03-08 - Bret Scott
# V2 - 03/16/2021 - Bret Scott -- enhanced logging
# V3 - 03/26/2021 - Bret Scott -- added logic to determine for which zone it is running . Forced to hostname, lowercase
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
COLLECTOR_DATEFILE=${LOCAL_COLLECTOR_DIR}/.datefile
COLLECTOR_DATE=$(cat ${COLLECTOR_DATEFILE})

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

# Redirect STDOUT & STDERR to logfile 
[[ -d ${LOCAL_COLLECTOR_DIR}/log ]] || mkdir -p ${LOCAL_COLLECTOR_DIR}/log
exec > ${LOCAL_COLLECTOR_DIR}/log/collector_transfer-${TODAY}.log 2>&1 

# Enumerate the files to be transfered
echo -e "++Executing $0 on hostname: ${HOSTNAME} for date: ${TODAY}: Security Zone: ${SECURITY_ZONE}"
echo -e "\n\n++Enumerating files to be transfered for ${COLLECTOR_DATE}:"
find ${LOCAL_COLLECTOR_DIR}/output -name "collector-*-${COLLECTOR_DATE}.out*" -print
COLLECTOR_FILES=$(find ${LOCAL_COLLECTOR_DIR}/output -name "collector-*-${COLLECTOR_DATE}.out*" -print)

# Loop through the COLLECTOR_FILES and scp them to STF_UTILITY_SERVER
echo -e "\n++Execute scp commands to ${STF_UTILITY_SERVER}:"

REMOTE_OS_TYPE=$(ssh ${COLLECTOR_USER}@${STF_UTILITY_SERVER} uname)

case ${REMOTE_OS_TYPE} in
	SunOS)  REMOTE_COLLECTOR_DIR="$(ssh ${COLLECTOR_USER}@${STF_UTILITY_SERVER} getent passwd ${COLLECTOR_USER} | cut -d: -f6  )/collector" ;;
	Linux)  REMOTE_COLLECTOR_DIR="$(ssh ${COLLECTOR_USER}@${STF_UTILITY_SERVER} getent passwd ${COLLECTOR_USER} | cut -d: -f6  )/collector" ;;
	AIX)    REMOTE_COLLECTOR_DIR="$(ssh ${COLLECTOR_USER}@${STF_UTILITY_SERVER} lsuser -c -a home ${COLLECTOR_USER} | grep -v "#" | cut -d: -f2 )/collector" ;;
esac

## Make the REMOTE_COLLECTOR_DIR/output on STF_UTILITY_SERVER if it does not exist
ssh ${COLLECTOR_USER}@${STF_UTILITY_SERVER} "[[ -d ${REMOTE_COLLECTOR_DIR}/output ]] || mkdir -p ${REMOTE_COLLECTOR_DIR}/output"

## Loop through the files with COLLECTOR_DATE in the filename
for FILE in ${COLLECTOR_FILES}
do
	## Strip off the directory info
	FILE_BASENAME=$(basename ${FILE})
	echo -e "\n++scp ${FILE} ${COLLECTOR_USER}@${STF_UTILITY_SERVER}:${REMOTE_COLLECTOR_DIR}/output/${FILE_BASENAME}"
	SUCCESS=0

	# Copy the FILE_BASENAME to the REMOTE_COLLECTOR_DIR/output/FILE_BASENAME and check if successful
	md5sum ${FILE} > ${FILE}.md5
	scp ${FILE} ${COLLECTOR_USER}@${STF_UTILITY_SERVER}:${REMOTE_COLLECTOR_DIR}/output/${FILE_BASENAME}
        [[ $? -eq 0 ]] && SUCCESS=1  || SUCCESS=0

	scp ${FILE}.md5 ${COLLECTOR_USER}@${STF_UTILITY_SERVER}:${REMOTE_COLLECTOR_DIR}/output/${FILE_BASENAME}.md5
        [[ $? -eq 0 ]] && SUCCESS=1  || SUCCESS=0

	# Make sure the copied file has the correct md5sum
        SUCCESS=$(ssh ${COLLECTOR_USER}@${STF_UTILITY_SERVER} "md5sum --quiet -c ${REMOTE_COLLECTOR_DIR}/output/${FILE_BASENAME}.md5 && echo 1 || echo 0")

	# Output a message 
        case ${SUCCESS} in
                1) echo -e "\t=>SUCCESS:: Successful scp transfer of ${FILE}  to ${STF_UTILITY_SERVER}:${REMOTE_COLLECTOR_DIR}/output/${FILE_BASENAME}. " 
		   rm -f ${FILE}.md5
                   ssh ${COLLECTOR_USER}@${STF_UTILITY_SERVER} rm -f  ${REMOTE_COLLECTOR_DIR}/output/${FILE_BASENAME}.md5 
		   ;;

                0) echo -e "\t=>ERROR:: Error during scp transfer of ${FILE}  to ${STF_UTILITY_SERVER}:${REMOTE_COLLECTOR_DIR}/output/${FILE_BASENAME}" ;;
	esac

done


## CLeanup any collector files that are older than DAYS_TO_KEEP
echo -e "\n\n++Cleaning up the following transfer logfiles..."
find ${LOCAL_COLLECTOR_DIR}/log -name "collector_transfer*.log" -mtime +${DAYS_TO_KEEP} -print
find ${LOCAL_COLLECTOR_DIR}/log -name "collector_transfer*.log" -mtime +${DAYS_TO_KEEP} -exec rm {} \;
##
exit 0

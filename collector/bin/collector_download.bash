#!/bin/bash 
#
# collector_download.bash:
# bash script to download the collector output files from the defined
# endpoint unix / linux servers 
#
# V1 - 03/08/2021 - Bret Scott
# V2 - 03/16/2021 - Bret Scott -- added additional logic to determine COLLECTOR_USER homedir; enhanced logging etc.;
# V3 - 03/26/2021 - Bret Scott -- added logic to determine which zone it is running for based on hostname, forced to use short hostname, lowercase
# V4 - 09/07/2021 - Bret Scott -- added step to chmod downloaded files , added ssh/scp options for BatchMode=Yes and PasswordAuthentication=no on the command line
# V5 - 09/23/2021 - Bret Scott -- added workaround for the syntax issue in the collector_wrapper.sh script for the Solaris and AIX hosts
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
COLLECTOR_DATE=${TODAY}
SSH_WITH_OPTIONS="ssh -o BatchMode=Yes -o PasswordAuthentication=no "
SCP_WITH_OPTIONS="scp -o BatchMode=Yes -o PasswordAuthentication=no "


umask 022

case ${HOSTNAME} in
	b3vprdruinf01) 	SECURITY_ZONE=INT 
			STF_UTILITY_SERVER=sfvprdruinf01
			;;

	b3vprdruinf02) 	SECURITY_ZONE=PII 
			STF_UTILITY_SERVER=sfvprdruinf02
			;;

	b3vprdruinf03) 	SECURITY_ZONE=DMZ 
			STF_UTILITY_SERVER=sfvprdruinf03
			;;
	
	*) 		echo -e "\n ERROR:: ${0} cannot run on ${HOSTNAME}.  Exiting"
			;;
esac


# Set the COLLECTOR_DATEFILE for use in transfer script
echo -e ${COLLECTOR_DATE} > ${COLLECTOR_DATEFILE}

# Redirect STDOUT & STDERR to logfile
mkdir -p ${LOCAL_COLLECTOR_DIR}/log
exec > ${LOCAL_COLLECTOR_DIR}/log/collector_download-${TODAY}.log 2>&1 

# Read the COLLECTOR_ENDPOINTS file and get the list of hostnames from which to collect
ENDPOINTS=$(egrep -v "^\s*#|^\s*$" ${COLLECTOR_ENDPOINTS} | grep -i ${SECURITY_ZONE} | awk -F: '{print $1}' )
echo -e "++Executing $(basename $0) on hostname: ${HOSTNAME} for date: ${TODAY}: Security Zone: ${SECURITY_ZONE} "
echo -e "\n++Downloading collector.out files from the following endpoints in Security Zone: ${SECURITY_ZONE}:"
echo -e "${ENDPOINTS}"

# Create the output directory if necessary
[[ -d ${LOCAL_COLLECTOR_DIR}/output ]] || mkdir -p ${LOCAL_COLLECTOR_DIR}/output

# Loop through the ENDPOINTS and scp the remote collector.out files appending today's date
echo -e "\n\n++Execute scp commands to endpoints:"
for ENDPOINT in ${ENDPOINTS}
do
	ENDPOINT=${ENDPOINT,,}
	ENDPOINT_OS_TYPE=$(${SSH_WITH_OPTIONS} ${COLLECTOR_USER}@${ENDPOINT} uname)

	case ${ENDPOINT_OS_TYPE} in
		SunOS) 	REMOTE_COLLECTOR_DIR="$(${SSH_WITH_OPTIONS} ${COLLECTOR_USER}@${ENDPOINT} getent passwd ${COLLECTOR_USER} | cut -d: -f6  )/collector" ;;
		Linux)  REMOTE_COLLECTOR_DIR="$(${SSH_WITH_OPTIONS} ${COLLECTOR_USER}@${ENDPOINT} getent passwd ${COLLECTOR_USER} | cut -d: -f6  )/collector" ;;
		AIX) 	REMOTE_COLLECTOR_DIR="$(${SSH_WITH_OPTIONS} ${COLLECTOR_USER}@${ENDPOINT} lsuser -c -a home ${COLLECTOR_USER} | grep -v "#" | cut -d: -f2 )/collector" ;;
	esac

	echo -e "\n++${SCP_WITH_OPTIONS} ${COLLECTOR_USER}@${ENDPOINT}:${REMOTE_COLLECTOR_DIR}/output/collector-${ENDPOINT}.out ${LOCAL_COLLECTOR_DIR}/output/collector-${ENDPOINT}-${SECURITY_ZONE}-${COLLECTOR_DATE}.out"

	SUCCESS=0

# 9/14/2021
# Added logic to fix the error in the endpoint_wrapper.sh script -- it adds an "L" to the collector-$(hostname).out so it results in collector-L$(hostname).out
#
        case ${ENDPOINT_OS_TYPE} in
		Linux) 	${SCP_WITH_OPTIONS} ${COLLECTOR_USER}@${ENDPOINT}:${REMOTE_COLLECTOR_DIR}/output/collector-${ENDPOINT}.out ${LOCAL_COLLECTOR_DIR}/output/collector-${ENDPOINT}-${SECURITY_ZONE}-${COLLECTOR_DATE}.out
			${SCP_WITH_OPTIONS} ${COLLECTOR_USER}@${ENDPOINT}:${REMOTE_COLLECTOR_DIR}/output/collector-${ENDPOINT}.out.err ${LOCAL_COLLECTOR_DIR}/output/collector-${ENDPOINT}-${SECURITY_ZONE}-${COLLECTOR_DATE}.out.err
			;;

		*) ${SCP_WITH_OPTIONS} ${COLLECTOR_USER}@${ENDPOINT}:${REMOTE_COLLECTOR_DIR}/output/collector-L${ENDPOINT}.out ${LOCAL_COLLECTOR_DIR}/output/collector-${ENDPOINT}-${SECURITY_ZONE}-${COLLECTOR_DATE}.out
			${SCP_WITH_OPTIONS} ${COLLECTOR_USER}@${ENDPOINT}:${REMOTE_COLLECTOR_DIR}/output/collector-L${ENDPOINT}.out.err ${LOCAL_COLLECTOR_DIR}/output/collector-${ENDPOINT}-${SECURITY_ZONE}-${COLLECTOR_DATE}.out.err
			;;
	esac

	chmod 644 ${LOCAL_COLLECTOR_DIR}/output/collector-${ENDPOINT}-${SECURITY_ZONE}-${COLLECTOR_DATE}.out*

	[[ $? -eq 0 ]] && SUCCESS=1  || SUCCESS=0 
	[[ -s ${LOCAL_COLLECTOR_DIR}/output/collector-${ENDPOINT}-${SECURITY_ZONE}-${COLLECTOR_DATE}.out ]] && SUCCESS=1 || SUCCESS=0

	case ${SUCCESS} in 
		1) echo -e "\t=>SUCCESS:: Successful scp transfer of ${COLLECTOR_USER}@${ENDPOINT}:${REMOTE_COLLECTOR_DIR}/output/collector-${ENDPOINT}.out to ${LOCAL_COLLECTOR_DIR}/output/collector-${ENDPOINT}-${SECURITY_ZONE}-${COLLECTOR_DATE}.out" 
		;;

		0) echo -e "\t=>ERROR: Error during scp of ${COLLECTOR_USER}@${ENDPOINT}:${REMOTE_COLLECTOR_DIR}/output/collector-${ENDPOINT}.out to ${LOCAL_COLLECTOR_DIR}/output/collector-${ENDPOINT}-${SECURITY_ZONE}-${COLLECTOR_DATE}.out" 
		;;
	esac
done

# Cleanup old files according to DAYS_TO_KEEP
echo -e "\n\n++Cleaning up the following collector files..."
find ${LOCAL_COLLECTOR_DIR}/output -name "collector-*out" -mtime +${DAYS_TO_KEEP} -print
find ${LOCAL_COLLECTOR_DIR}/output -name "collector-*out" -mtime +${DAYS_TO_KEEP} -exec rm {} \;
echo -e "\n++Cleaning up the following download logfiles..."
find ${LOCAL_COLLECTOR_DIR}/log -name "collector_download*.log" -mtime +${DAYS_TO_KEEP} -print
find ${LOCAL_COLLECTOR_DIR}/log -name "collector_download*.log" -mtime +${DAYS_TO_KEEP} -exec rm {} \;
##
exit 0

#!/bin/sh
#
# collector_wrapper.sh:
# Wrapper script to execute the collector script from cron which 
# will then change the ownership to the defined user for subsequent pickup
# from the DR utility server.
#
# V1 - 2021-03-08 - Bret Scott
# V2 - 2021-03-16 - Bret Scott --- added logging etc, determination of COLLECTOR_USER homedir etc..
# V3 - 2021-03-26 - Bret Scott --- Added logic to switch to bash shell , changed hostname to be the "short" hostname, forced hostname to lowercase
#
#
if [ "$RANDOM" = "$RANDOM" ]; then
        for sh in /bin/bash /usr/bin/bash
        do
                [ -x $sh ] && exec $sh $0 $*
        done
        exit 1
fi

COLLECTOR_SCRIPT=collector-1.14
COLLECTOR_USER=drutladm

## Get the COLLECTOR_USER homedir based on OS_TYPE and set the LOCAL_COLLECTOR_DIR

OS_TYPE=$(uname)
case ${OS_TYPE} in
        SunOS) LOCAL_COLLECTOR_DIR="$(getent passwd ${COLLECTOR_USER} | cut -d: -f6  )/collector" 
                HOSTNAME=$(hostname | cut -d "." -f1 | sed -e 's/\(.*\)/\L\1/' )
                ;;

        Linux)  LOCAL_COLLECTOR_DIR="$(getent passwd ${COLLECTOR_USER} | cut -d: -f6  )/collector" 
                HOSTNAME=$(hostname -s | sed -e 's/\(.*\)/\L\1/' )
                ;;
                
        AIX)    LOCAL_COLLECTOR_DIR="$(lsuser -c -a home ${COLLECTOR_USER} | grep -v "#" | cut -d: -f2 )/collector" 
                HOSTNAME=$(hostname | cut -d "." -f1  | sed -e 's/\(.*\)/\L\1/' )
                ;;
	
	*)	exit 1 ;;
esac

DATE_TIME=$(date '+%m/%d/%Y_%H:%M:%S')
COLLECTOR_OUTPUT=${LOCAL_COLLECTOR_DIR}/output/collector-${HOSTNAME}.out
COLLECTOR_LOGFILE=${LOCAL_COLLECTOR_DIR}/log/collector-${HOSTNAME}.log

## Trim the COLLECTOR_LOGFILE to 100 lines
if [[ -f ${COLLECTOR_LOGFILE} ]] 
then 
	tail -100 ${COLLECTOR_LOGFILE} > ${COLLECTOR_LOGFILE}.tmp
	mv ${COLLECTOR_LOGFILE}.tmp ${COLLECTOR_LOGFILE}
fi

# Make sure LOCAL_COLLECTOR_DIR is owned by COLLECTOR_USER
[[ -d ${LOCAL_COLLECTOR_DIR}/log ]] || mkdir -p ${LOCAL_COLLECTOR_DIR}/log
chown -R ${COLLECTOR_USER} ${LOCAL_COLLECTOR_DIR}/

# Make sure COLLECTOR_SCRIPT is executable
[[ -x ${LOCAL_COLLECTOR_DIR}/bin/${COLLECTOR_SCRIPT} ]] || chmod +x ${LOCAL_COLLECTOR_DIR}/${COLLECTOR_SCRIPT}

# Run COLLECTOR_SCRIPT sending output to COLLECTOR_OUTPUT
${LOCAL_COLLECTOR_DIR}/bin/${COLLECTOR_SCRIPT} stdout > ${COLLECTOR_OUTPUT} 2>${COLLECTOR_OUTPUT}.err

case $? in 
	0) echo -e "SUCCESS:: ${COLLECTOR_SCRIPT} ran to completion at ${DATE_TIME} -- find  output file at ${COLLECTOR_OUTPUT} " >> ${COLLECTOR_LOGFILE} ;;
	*) echo -e "WARNING:: ${COLLECTOR_SCRIPT} resulted in error at ${DATE_TIME} -- see error file at ${COLLECTOR_OUTPUT}.err " >> ${COLLECTOR_LOGFILE} ;;
esac

# Change ownership of resulting files
chown ${COLLECTOR_USER} ${COLLECTOR_OUTPUT} ${COLLECTOR_OUTPUT}.err ${COLLECTOR_LOGFILE}
##
exit 0

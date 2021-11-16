#!/bin/sh
#
# install_collector_scripts.sh
# Installer script for deploying the collector scripts framework
#
# V1 - 2021-03-26 - Bret Scott
# V2 - 2021-06-09 - Bret Scott -- ADDED the ssh key "from" statement
#
if [ "$RANDOM" = "$RANDOM" ]; then
        for sh in /bin/bash /usr/bin/bash
        do
                [ -x $sh ] && exec $sh $0 $*
        done
        exit 1
fi

COLLECTOR_USER=drutladm
TODAY=$(date '+%Y%m%d')

DoExit() {
	case $1 in
		1) echo -e "ERROR:: Incorrect value supplied for -z argument -- must be one of DMZ, PII, or INT\n" ;;
		2) echo -e "ERROR:: ${INSTALL_FILE} provided with -f option is not accessible or invalid!\n" ;;
		3) echo -e "ERROR:: ${0} must be run as root user!\n" ;; 
		4) echo -e "ERROR:: Errors encountered extracing ${INSTALL_FILE}.  Please investigate!\n" ;;
		99) echo -e "ERROR:: Not a supported platform\n" ;;
		0) echo -e "\nSUCCESS:: \n" ;;
	esac
	exit $1
}

DoHelp() {
	echo -e "Usage:\n"
	echo -e "$0 -z <SECURITY_ZONE> :: (Supply one of DMZ,PII,INT)"
	echo -e "   -f <INSTALL TARFILE >"
	echo -e "   -h :: Print this message"
	exit 1
}

while getopts "z:f:h" opt; do
case ${opt} in
	z)	SECURITY_ZONE=$OPTARG ;;
	f)	INSTALL_FILE=$OPTARG ;;
	h)	DoHelp ;;
	*)	DoHelp ;;
esac
done

OS_TYPE=$(uname)
case ${OS_TYPE} in
        SunOS)  LOCAL_COLLECTOR_DIR=$(getent passwd ${COLLECTOR_USER} | cut -d: -f6  )
                HOSTNAME=$(hostname | cut -d "." -f1 )
                ;;

        Linux)  LOCAL_COLLECTOR_DIR=$(getent passwd ${COLLECTOR_USER} | cut -d: -f6  )
                HOSTNAME=$(hostname -s )
                ;;

        AIX)    LOCAL_COLLECTOR_DIR=$(lsuser -c -a home ${COLLECTOR_USER} | grep -v "#" | cut -d: -f2 )
                HOSTNAME=$(hostname | cut -d "." -f1  )
                ;;

        *)      DoExit 99 ;;
esac



[[ ${SECURITY_ZONE} = "DMZ" ]] || [[ ${SECURITY_ZONE} = "INT" ]] || [[ ${SECURITY_ZONE} = "PII" ]] || DoExit 1
[[ -f ${INSTALL_FILE} ]] || DoExit 2
tar -tf ${INSTALL_FILE} > /dev/null 2>&1 || DoExit 2
[[ "${USER}" = "root" ]] || DoExit 3

# Unpack tar file
echo -e "\nUnpacking ${INSTALL_FILE} in ${LOCAL_COLLECTOR_DIR}...\n"
chmod +r ${INSTALL_FILE}
su - ${COLLECTOR_USER} -c "cd ${LOCAL_COLLECTOR_DIR}; tar -xvf ${INSTALL_FILE} && echo -e '\n++Successfully Unpacked ${INSTALL_FILE} in ${LOCAL_COLLECTOR_DIR}...\n'" || DoExit 4

echo -e "\nAdding public key to authorized_keys file...\n"

case ${SECURITY_ZONE} in
	DMZ) SSHKEY="from=\"161.178.190.124,10.235.32.185,10.235.128.32\" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDU+uDUoDCxP7c936eJZinE+heR0FnAot8qy+GI8usHwdHvrtRw/aBzo1wN1zP5tSbvE1jXSka3f4tDtHsS+OZztGQSvr4CFpb/hnBlK/aU8H0QAsN/sb+BsCJA1J2PqIIW2boiUCL2Rx+T8E99Gbk8uRxbsbd7TI0if8pwDUwcPmkUF7MQdQ4z3x1pyKhr+tNZ9BbMAA5FKHfrqF5OK1eBYtMX6+CsQn0kBYSU/FHDghnS9UwxmGQwrzahb4NBAxBd8YaxCqBlRqEfM+5+Y+lhHEO81oRbWXX9gVQiKbGVKkh7hc70agcdnBkE/+KYj1ouYHbdUXkmbWJDXY0mNOUzk/234TcT/mbp+PhGn1RUqBlOtAKA7N4J3EAqW7T0cjc1L7WSiG0PIuYr4wefIytvp9Kw1iJJUI2jqHkSjaoHf1zTvIRPoKCJQJyT+q1emk1CxtQQJ/+o6vcBcKSDaeu8bQakmBBB01GHsjMruJfhUvy34mWSdn+G4JT2ki0oMxfD4rQg85hxWJ6lol9Sopw8tw5JBhFaHEuixUuqU4Ip+so8d61APfK5vGv35QjHG4yFoxbTkyhXm2Ngye5S30Pggvg4lsggHk65AtP6+m/ylyJ4XcBfOyOkRabiHZ8HjFezVKyjT50qwYCNnOXmvcUBrZvI74YgRC3YdGU4x4h7nw== For DR Utility Admin Access" 
		;;
	PII) SSHKEY="from=\"161.178.190.124,10.235.32.185,10.235.128.32\" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCm/6+bQqxxhKkZxUvHPEfH+m1k5Sm7I9Uwyh7BhecYEADZlyjLcwXQaXF+lE0D/rbhVTB8gNlvsX5gbdj6qb4XK7vXz4KdKFWFnX81axJZ5wu0mrEtMq1k1Rfgyawyvt0Me0Z5sHUGOF1n06zXwjF3sdPJmoPLncfnzTXYGLiPL4Qka3TugEiDnl7Ta/HTStKme1Cv0ofpdfBgTwiFLhYj8u/QeoDYBhKCulakFdZDaiE+Wlt0xWyold5batNPpkKqq8hxlbpOQIyBo+7/2gytK+WpDk2WpX0lbO/gKDRRxu2pGC156GA2ci8wGtAeGkT2ZJxpkBKejM4mp00ThJHxPKPD/sI5v4abt1f8Kc9VYFzsOn0WSR70q0gtOVQEI8KA7ihZ2wW/DidiauGCRnrtVf3zmzkPPH7RgV+TY/5ql7rrfmjRIbuJM1m8hlJv32yBHlTT65Ubhpzcj+skhTb6qr0MqqpGJPrQV+Uxta6ohIzfRE5ZmsaYnQcsQKPNznsJFXO7uoStRCteLhifVidZ5tQYRr4hCCl1Y4+Tgm0mBRjB3ou4TWscxf/Skbc2CsT8HSa7+cmpJJJH7/1N2+skC8uPuckcQdd4FokqMRqr3uN/Zc4LXIdpPVLFBWP7WmZt7Hc9hRNvzS+f7hsGYtPmyKk3HkqYzZIgVCsrI6QmWw== For DR Utility Admin Access" 
		;;
	INT) SSHKEY="from=\"161.178.190.124,10.235.32.185,10.235.128.32\" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDNUcjTJCYbKjjtM11zYyaZiq3SH0Ls8jjgVdGotrnoIkSBcr9M1/2L9EcMpbRh9ex4Fg/1LhCLsr6UOP/jxHoPSVqxGexhS0bBHMkVSxkTswZpQujN1iNv/apClTE56olpf9SvJG2dMqF2+FDiOKDDABX+dE7ijiyw6KUIRKLy48biPj1Bo17Ej9KcouuJTfSRgDzg09NyFyrbrUtVObXoO2HTlRH7QvzgNVDZ3BeWsMiaA7iOY/boRS/e4sVh+WkAUryAggcaS+ED8Cd7qzSu5M7ehx4I9y0XziHcLtN/zFOK6hfMP+Z9jguV5a+JNNhwZs25LnB6AHWELaRXKjQF689um6Ui+U4YVswDop9Ch+yIglAPsUTUbGUJFzcLKLNtLoLGpTkKullmLC7GSJyptE7hVobuGu9GvLis+qWm2BLUvY+Fqp960FyjnWDPN4h4WuPJeFQ87mhhLhNBFFH0NwwrTntoz0Q783PsyGsgiDRXSuTg6xr7Nyqe46eW66v9TjX8x4+U5yGMNb93PJNuBw3gv7Wf+/s7agEm12ig9AIYxRMZoMQgjaq9gkPN631WZebAgJ8TOFbHjV7gjxrCniQ4iOOpXpeU85e1aVqPP/G7MNbKUD8GhysP0AOd1DmiBC5+qpp8VBIxSZWEUi8Rwpjs9+CRc+VpNneWHZQOWQ== For DR Utility Admin Access"
		;;
esac

su - ${COLLECTOR_USER} -c "mkdir -p ${LOCAL_COLLECTOR_DIR}/.ssh; echo ${SSHKEY} >> ${LOCAL_COLLECTOR_DIR}/.ssh/authorized_keys && echo -e '\n++Successfully added public key to ${LOCAL_COLLECTOR_DIR}/.ssh/authorized_keys...\n'" || DoExit 5

su - ${COLLECTOR_USER} -c "chmod 700 ${LOCAL_COLLECTOR_DIR}/.ssh; chmod 600 ${LOCAL_COLLECTOR_DIR}/.ssh/authorized_keys; ls -ld ${LOCAL_COLLECTOR_DIR}/.ssh/; ls -l ${LOCAL_COLLECTOR_DIR}/.ssh/authorized_keys"

echo -e "\n++New authorized_keys file...\n====<snip>===="
su - ${COLLECTOR_USER} -c "cat ${LOCAL_COLLECTOR_DIR}/.ssh/authorized_keys"
echo -e "====</snip>===="


echo -e "\n\n++Add root crontab entry for endpoint collection...\n"
TMPCRONTAB=crontab.${RANDOM}
crontab -l > root-crontab-${TODAY}.sav
crontab -l > ${TMPCRONTAB}

echo -e "##\n## Added by ${0} on ${TODAY}" >> ${TMPCRONTAB}
echo -e "0 0 1 * * ${LOCAL_COLLECTOR_DIR}/collector/bin/collector_wrapper.sh > /dev/null 2>&1" >> ${TMPCRONTAB}
echo -e "##" >> ${TMPCRONTAB}

crontab ${TMPCRONTAB}
echo -e "\n++New root crontab:"
crontab -l 
rm ${TMPCRONTAB}	   

DoExit 0

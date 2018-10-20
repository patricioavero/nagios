#!/bin/bash
##
## DISCLAIMER: This is meant for Personal Use.
## STATUS: Ongoing
## WHAT: This is a personal Nagios installer
## GOAL: Install Nagios on RHEL or CentOS GNU/Linux Distro.

## Variables
DATE=`date +%F`
TIME=`date +%T`
PID=$$
OS_NAME=`grep "^ID\b" /etc/os-release | cut -d "=" -f2 | cut -d "\"" -f2`
LOG_FILE="./nagios-installer_${PID}_${DATE}-${TIME}.log"
PKGS2INSTALL="httpd php gcc glibc glibc-common make gd gd-devel net-snmp"
USER_NAGIOS="nagios"
GROUP_NAGIOS="nagcmd"

## Functions

log2file () {
	local STR=$1
	local DATE=`date +%F`
	local TIME=`date +%T`

	echo "${DATE}@${TIME} - ${STR}" | tee -a $LOG_FILE
}

install_pkg () {
	local PKG=$1

	log2file "Installing the package ${PKG}..."
	yum install -y ${PKG}
	local PKG_INST_RESULT=$?

	if [ ${PKG_INST_RESULT} -eq 0 ]
	then
		log2file "The installation of ${PKG} has been successfully accomplished."
	else
		log2file "Something appear to went wrong with the installation of ${PKG}."
	fi
}

check_installed_pkg () {
	local PKG=$1

	log2file "Checking if ${PKG} is installed"

	PKG_SEARCH=`rpmquery ${PKG}`
	local EXIT_CODE=$?

	if [ ${EXIT_CODE} -eq 0 ]
	then
		log2file "The package ${PKG} is installed"
		return 10
	else
		log2file "The package ${PKG} is not installed"
		return 11
	fi


}

create_user () {
	local USER=$1

	useradd ${USER} -g ${GROUP_NAGIOS} 2>/dev/null
	local RESULT=$?

	if [ ${RESULT} -eq 0 ]
	then
		log2file "The user ${USER} has been successfully added."
	elif [ ${RESULT} -eq 9 ]
	then
		log2file "The user ${USER} is already in the system."
	fi
	
}

create_group () {
	local GROUP=$1

	useradd ${GROUP} 2>/dev/null
	local RESULT=$?

	if [ ${RESULT} -eq 0 ]
	then
		log2file "The group ${GROUP} has been successfully added."
	elif [ ${RESULT} -eq 9 ]
	then
		log2file "The group ${GROUP} is already in the system."
	fi
	
}

## MAIN
log2file "======================================================"
log2file "| What: Starting the Nagios Installer"
log2file "| Who: ${USER}"
log2file "| When: ${DATE}@${TIME}"
log2file "| Where: ${HOSTNAME}"
log2file "======================================================"
log2file ""
log2file ""

## Check if the user is root or not
if [ "${EUID}" != 0 ]
then
	log2file "======================================================"
	log2file "| Warning:"
	log2file "|"
	log2file "| The user to run this installer MUST be root"
	log2file "| Exiting for now..."
	log2file "======================================================"
	log2file ""
	exit 3
fi

## Install the EPEL repository

check_installed_pkg epel-release
EXIT_CODE=$?

if [ ${EXIT_CODE} -eq 11 ]
then
	PKG_EPEL=epel-release
	if [ "${OS_NAME}" == "centos" ]
	then
		log2file "Installing EPEL repo base on Centos 7 method"
		install_pkg ${PKG_EPEL}

	elif [ "${OS_NAME}" == "rhel"]
	then
		log2file "Instsalling EPEL repo base on RHEL 7 method"
		install_pkg https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
	fi
fi
## [ END EPEL ] ##########################


## Start the installation of needed packages
for i in `echo ${PKGS2INSTALL}`
do
	check_installed_pkg ${i}
	EXIT_CODE=$?
	#echo ${EXIT_CODE}

	if [ ${EXIT_CODE} -eq 11 ]
	then
		echo "Installing the Package: ${i}"
		install_pkg ${i}
	fi

done
## [ END Packages Installation ] ##########

## Users and Groups creation ##############
create_group ${GROUP_NAGIOS}
create_user ${USER_NAGIOS}

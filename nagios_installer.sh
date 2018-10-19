#!/bin/bash
## This is the a personal Nagios installer

## Variables
DATE=`date +%F`
TIME=`date +%T`
PID=$$
OS_NAME=`grep "^ID\b" /etc/os-release | cut -d "=" -f2 | cut -d "\"" -f2`
LOG_FILE="./nagios-installer_${PID}_${DATE}-${TIME}.log"
PKGS2INSTALL="httpd php gcc glibc glibc-common make gd gd-devel net-snmp"
#PKGS2INSTALL="httpd"

## Functions

log2file () {
	local STR=$1
	local DATE=`date +%F`
	local TIME=`date +%T`

	echo "${DATE}@${TIME} - ${STR}" | tee -a $LOG_FILE
}

install_pkg () {
	local PKG=$1

	log2file "Installing the package ${PKG}"
	yum install -y ${PKG}
	local PKG_INST_RESULT=$?

	if [ ${PKG_INST_RESULT} -eq 0 ]
	then
		log2file "The installation of ${PKG} has been successfully accomplished"
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


## MAIN
log2file "======================================================"
log2file "| What: Starting the Nagios Installer"
log2file "| Who: ${USER}"
log2file "| When: ${DATE}@${TIME}"
log2file "| Where: ${HOSTNAME}"
log2file "======================================================"
log2file ""
log2file ""

## Check if the user ir root
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

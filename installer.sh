#!/usr/bin/env bash

clear

echo "================================================"
echo "Staring the installation of:    "
echo ""
echo "  + Nagios Monitoring Tool"
echo "  + Nagios Plugins"
echo "  + PNP4Nagios"
echo ""
echo "================================================"

# Variables
nagios_version='4.4.5'
nagios_plugin_version='2.2.1'
pnp4nagios_version='0.6.26'

nagios_path='/usr/local/nagios'
nagios_cfg_file="${nagios_path}/etc/nagios.cfg"
nagios_commands_file="${nagios_path}/etc/objects/commands.cfg"
nagios_templates_file="${nagios_path}/etc/objects/templates.cfg"
pnp4nagios_commands='

##--------------------------------------------------------------------##
## Added from pnp4nagios
##--------------------------------------------------------------------##
define command{
       command_name    process-service-perfdata-file
       command_line    /bin/mv /usr/local/pnp4nagios/var/service-perfdata /usr/local/pnp4nagios/var/spool/service-perfdata.$TIMET$
}

define command{
       command_name    process-host-perfdata-file
       command_line    /bin/mv /usr/local/pnp4nagios/var/host-perfdata /usr/local/pnp4nagios/var/spool/host-perfdata.$TIMET$
}
##--------------------------------------------------------------------##

'
pnp4nagios_config='

##--------------------------------------------------------------------##
## Added from pnp4nagios
##--------------------------------------------------------------------##
# Activate Performance
process_performance_data=1

# service performance data
service_perfdata_file=/usr/local/pnp4nagios/var/service-perfdata
service_perfdata_file_template=DATATYPE::SERVICEPERFDATA\tTIMET::$TIMET$\tHOSTNAME::$HOSTNAME$\tSERVICEDESC::$SERVICEDESC$\tSERVICEPERFDATA::$SERVICEPERFDATA$\tSERVICECHECKCOMMAND::$SERVICECHECKCOMMAND$\tHOSTSTATE::$HOSTSTATE$\tHOSTSTATETYPE::$HOSTSTATETYPE$\tSERVICESTATE::$SERVICESTATE$\tSERVICESTATETYPE::$SERVICESTATETYPE$
service_perfdata_file_mode=a
service_perfdata_file_processing_interval=15
service_perfdata_file_processing_command=process-service-perfdata-file

# host performance data
host_perfdata_file=/usr/local/pnp4nagios/var/host-perfdata
host_perfdata_file_template=DATATYPE::HOSTPERFDATA\tTIMET::$TIMET$\tHOSTNAME::$HOSTNAME$\tHOSTPERFDATA::$HOSTPERFDATA$\tHOSTCHECKCOMMAND::$HOSTCHECKCOMMAND$\tHOSTSTATE::$HOSTSTATE$\tHOSTSTATETYPE::$HOSTSTATETYPE$
host_perfdata_file_mode=a
host_perfdata_file_processing_interval=15
host_perfdata_file_processing_command=process-host-perfdata-file
##--------------------------------------------------------------------##

'

pnp4nagios_templates='

##--------------------------------------------------------------------##
## Added from pnp4nagios
##--------------------------------------------------------------------##
# Host Performace Data
define host {
name host-pnp
action_url /pnp4nagios/index.php/graph?host=$HOSTNAME$&srv=_HOST_' class='tips' rel='/pnp4nagios/index.php/popup?host=$HOSTNAME$&srv=_HOST_
register 0
}

# Service Performance Data
define service {
name srv-pnp
action_url /pnp4nagios/index.php/graph?host=$HOSTNAME$&srv=$SERVICEDESC$' class='tips' rel='/pnp4nagios/index.php/popup?host=$HOSTNAME$&srv=$SERVICEDESC$
register 0
}

'

grafana_repo='
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt'

# Functions
check () {
  result=${1}
  message=${2}

  if [[ ${result} -eq 0 ]]; then
    echo "OK: The step '${2}' has been successfully done."
  else
    echo "Error: something went wrong with '${2}'"
  fi

}

# Update the OS
yum update -y &>/dev/null
check $? "Update OS"

# Setup the Security Enhanced
sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config &>/dev/null
check $? "Disable SELinux"
setenforce 0 &>/dev/null
check $? "Current SELinux enforcing to Disabled"

# Install the Pre-requisites
yum install -y php-gd rrdtool rrdtool-perl perl-Time-HiRes perl-GD gcc glibc glibc-common wget unzip httpd php gd gd-devel perl postfix make automake autoconf openssl-devel net-snmp snmp-utils gettext perl-Net-SNMP epel-release postgresql-devel libdbi-devel openldap-devel mariadb-devel mariadb-libs bind-utils samba-client qstat fping openssh-clients lm_sensors check_mailq check_flexm lmstat &>/dev/null
check $? "Pre-requisites installation"

# Download Sources of Nagios Core
cd /var/tmp &>/dev/null
wget -O nagioscore.tar.gz https://github.com/NagiosEnterprises/nagioscore/archive/nagios-${nagios_version}.tar.gz &>/dev/null
check $? "Nagios Core tarball download"
tar xzf nagioscore.tar.gz &>/dev/null
check $? "Decompress and untar the nagios core tarball"

# Compile the downloaded Source
cd /var/tmp/nagioscore-nagios-${nagios_version}/ &>/dev/null
./configure &>/dev/null
check $? "Configure of Source"
make all &>/dev/null
check $? "Make of Source"

# Create User and Group
make install-groups-users &>/dev/null
check $? "Install Users and Groups"
usermod -a -G nagios apache &>/dev/null
check $? "Add apache to Nagios Group"

# Install the binaries
make install &>/dev/null
check $? "Binaries installation"

# Install the Daemon
make install-daemoninit &>/dev/null
check $? "Daemon installation"
systemctl enable httpd.service &>/dev/null
check $? "Daemon enable"

# Install the Command Mode
make install-commandmode &>/dev/null
check $? "Command Mode installation"

# Install the Configuration Files
make install-config &>/dev/null
check $? "Configuration Files installation"

# Install the Apache Configuration Files
make install-webconf &>/dev/null
check $? "Apache Configuration Files installation"

# Set up the firewall for the host
firewall-cmd --zone=public --add-port=80/tcp --permanent &>/dev/null
check $? "Add PORT 80 TCP"

# Create the Nagios Administration Account
htpasswd -c /usr/local/nagios/etc/htpasswd.users nagiosadmin &>/dev/null
check $? "Default Nagios Administration Account"

# Start the Apache Daemon
systemctl start httpd.service &>/dev/null
check $? "Start of the Apache Daemon"

# Start the Nagios Core
systemctl start nagios.service &>/dev/null
check $? "Start of Nagios Application"

# Download the Nagios's Plugins
cd /var/tmp
wget https://nagios-plugins.org/download/nagios-plugins-${nagios_plugin_version}.tar.gz &>/dev/null
check $? "Nagios Plugins Download"

# Decompress the Nagios plugins
cd /var/tmp
tar zxf nagios-plugins-${nagios_plugin_version}.tar.gz &>/dev/null
check $? "Decompress Nagios Plugins"

# Setup the plugins
#cd /var/tmp/nagios-plugins-${nagios_plugin_version}
#./tools/setup &>/dev/null
#check $? "Setup Nagios Plugins"

# Configure Nagios Plugins
cd /var/tmp/nagios-plugins-${nagios_plugin_version}
./configure &>/dev/null
check $? "Configure Nagios Plugins"

# Make the Nagios Plugins
make &>/dev/null
check $? "Make the Nagios Plugins"

# Make install Nagios Plugins
make install &>/dev/null
check $? "Make Nagios Plugins"

# Download PNP4Nagios
cd /var/tmp
wget https://razaoinfo.dl.sourceforge.net/project/pnp4nagios/PNP-0.6/pnp4nagios-${pnp4nagios_version}.tar.gz &>/dev/null
check $? "Download PNP4Nagios"

# Decompress the PNP4Nagios tarball
cd /var/tmp
tar zxf pnp4nagios-${pnp4nagios_version}.tar.gz &>/dev/null
check $? "Decompress PNP4Nagios"

# Configure PNP4 NagiosEnterprises
cd /var/tmp
cd pnp4nagios-${pnp4nagios_version}
./configure &>/dev/null
check $? "Configure PNP4Nagios"

# Make pnp4nagios
make all &>/dev/null
check $? "Make PNP4Nagios"

# Full install PNP4Nagios
make fullinstall &>/dev/null
check $? "PNP4Nagios Full Install"

# Change the current Process Performance Data value from 0 to 1 (Activate)
sed -i 's/process_performance_data=0/process_performance_data=1/g' ${nagios_cfg_file}
check $? "Process Performance Data Activation"

# Insert the PNP4Nagios configuration lines
echo "${pnp4nagios_config}" >> ${nagios_cfg_file}
check $? "Insert PNP4Nagios Configuration Lines to 'nagios.cfg'"

# Insert the PNP4Nagios commands lines
echo "${pnp4nagios_commands}" >> ${nagios_commands_file}
check $? "Insert PNP4Nagios Commands Files"

# Remove the pnp4nagios PHP Installation Files
mv /usr/local/pnp4nagios/share/install.php /usr/local/pnp4nagios/share/install.php.installed
check $? "Remove the PNP4Nagios PHP Installation File"

# Add PNP4Nagios Templates
echo "${pnp4nagios_templates}" >> ${nagios_templates_file}

# Download Grafana Software
#wget https://dl.grafana.com/oss/release/grafana-6.3.3-1.x86_64.rpm &>/dev/null
#check ?$ "Download Grafana"

# Install Grafana
#sudo yum localinstall grafana-6.3.3-1.x86_64.rpm &>/dev/null
#check $? "Install Grafana"

# Add Grafana Repository
echo "${grafana_repo}" > /etc/yum.repos.d/grafana.repo
check $? "Add Grafana Repository"

# Install Grafana via its Repository
yum install -y grafana &>/dev/null
check $? "Install Grafana"

# Add port for Grafana in the firewall
firewall-cmd --permanent --add-port=3000/tcp &>/dev/null
check $? "Add PORT 3000 TCP"

# Reload the firewall
firewall-cmd --reload &>/dev/null
check $? "Firewall Reload"

# Install PNP Plugin for Grafana
grafana-cli plugins install sni-pnp-datasource
check $? "PNP Pluging for Grafana Installation"



# sed -i '/Allow from all/a\        Allow from 127.0.0.1 ::1' /etc/httpd/conf.d/pnp4nagios.conf
# sed -i '/Require valid-user/a\        Require all granted' /etc/httpd/conf.d/pnp4nagios.conf
# sed -i 's/Allow from all/#&/' /etc/httpd/conf.d/pnp4nagios.conf
# sed -i 's/AuthName/#&/' /etc/httpd/conf.d/pnp4nagios.conf
# sed -i 's/AuthType Basic/#&/' /etc/httpd/conf.d/pnp4nagios.conf
# sed -i 's/AuthUserFile/#&/' /etc/httpd/conf.d/pnp4nagios.conf
# sed -i 's/Require valid-user/#&/' /etc/httpd/conf.d/pnp4nagios.conf

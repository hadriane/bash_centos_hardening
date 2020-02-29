#!/bin/bash

#Get date and time
CWD=$(pwd)
DT=$(date '+%d-%m-%Y_%H-%M-%S')
LOGFILE=$CWD/postdeploy-$DT.log
touch $LOGFILE

#This is the ESM Server hostname and IP Address
ESMSERVER='server54.staging.local'
ESMIPADD='1.1.1.1'
#This is the Localhost Server hostname and IP Address
HOSTNAME='IEPE1LTGCONP01'
HOSTNAMEIPADD='1.1.1.1'
#This is the Jumphost Server hostname and IP Address
JUMPHOSTNAME='jump-server1 jump-server1.production.local'
JUMPIPADD='172.16.0.18'
#This is the Osirium Server hostname and IP Address
OSIRIUMSERVER='osirium10app osirium'
OSIRIUMIPADD='172.16.10.17'
#This is the NTP Server  IP Address
NTPIPADD='169.254.169.123'

#This are all the servers that need to be removed from the ntp.conf file
NTPREMOVESERVERS=('server 0.centos.pool.ntp.org iburst' 'server 1.centos.pool.ntp.org iburst' 'server 2.centos.pool.ntp.org iburst' 'server 3.centos.pool.ntp.org iburst' '169.254.169.123')


#This is all the packages that needs to be instlled on the server
PACKAGESARRAY=('dejavu-serif-fonts-2.33-6.el7.noarch' 'dejavu-fonts-common-2.33-6.el7.noarch' 'dejavu-sans-fonts-2.33-6.el7.noarch' 'fontconfig-2.13.0-4.3.el7.x86_64' 'fontpackages-filesystem-1.44-8.el7.noarch' 'freetype-2.8-12.el7_6.1.x86_64' 'libpng-1.5.13-7.el7_2.x86_64')


echo "=== Ensure noexec option set on /dev/shm partition (BR10)===" > $LOGFILE

#Check if backup file for fstab exist
echo "1A - Checking if backup file for fstab exist." >> $LOGFILE
if [ ! -f /etc/fstab.arcmc2.0.orig ]; then
	echo "1B - Backup of fstab file does not exist. Creating backup for fstab file 'fstab.arcmc2.0.orig'." >> $LOGFILE
	#Backup fstab file
	cp '/etc/fstab' '/etc/fstab.arcmc2.0.orig'
else
	echo "1C - Backup of fstab file (/etc/fstab.arcmc2.0.orig) already exist." >> $LOGFILE
fi



#Check if /dev/shm line in fstab exist. If yes, remove it and add new /dev/shm line. If no, add new /dev/shm line.
echo "1D - Checking if /dev/shm line exist in /etc/fstab" >> $LOGFILE
SHM_LINE_FSTAB=$(sed -n "/\/dev\/shm/p" '/etc/fstab')

if [ ! -z "$SHM_LINE_FSTAB" ]; then
	echo "1E - /dev/shm line in fstab file exists. This line will be deleted and replaced with a new line." >> $LOGFILE
	#Delete line containing /dev/shm in fstab file
	sed -i "/\/dev\/shm/d" '/etc/fstab'
	#Insert the below line in fstab file 
	echo "tmpfs	/dev/shm	tmpfs	defaults,nodev,nosuid,noexec	0 0" >> '/etc/fstab'
else
	echo "1F - /dev/shm line in fstab file does not exists. It will be inserted into fstab file." >> $LOGFILE
	#Insert the below line in fstab file 
	echo "tmpfs	/dev/shm	tmpfs	defaults,nodev,nosuid,noexec	0 0" >> '/etc/fstab'
fi	


#Check if /dev/shm is mounted
echo "1G - Checking if /dev/shm is mounted" >> $LOGFILE
SHM_MOUNT="$(mount | grep shm)"

if [ ! -z "$SHM_MOUNT" ]; then
	echo "1H - /dev/shm is mounted." >> $LOGFILE
	#Check if noexec option is set for /dev/shm
	if [[ $SHM_MOUNT == *"noexec"* ]]; then
		echo "1I - noexec option is set for /dev/shm partition." >> $LOGFILE
	else
		#Unmount and remount /dev/shm partition
		echo "1J - noexec option is not set for /dev/shm partition. Unmounting and remounting /dev/shm partition." >> $LOGFILE
		umount /dev/shm
		mount /dev/shm
		mount -o remount /dev/shm
	fi
else
	#Mount and remount /dev/shm partition
	echo "1K - /dev/shm is not mounted. Mounting /dev/shm partition." >> $LOGFILE
	mount /dev/shm
	mount -o remount /dev/shm
fi



echo "=== Ensure sticky bit is set on all world-writable directories (BR14)===" >> $LOGFILE

#Check if world writable directories exist
WORLD_DIR=$(df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -type d -perm -0002 2>/dev/null)
if [ ! -z "$WORLD_DIR" ]; then
	echo "2A - World writable directories exist. There are the directories:" >> $LOGFILE
	echo "$WORLD_DIR" >> $LOGFILE
	#df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -type d -perm -0002 2>/dev/null | xargs chmod a+t
else
	echo "2B - There are no world writable directories found." >> $LOGFILE
fi

#Check if stick bit is set for world writable directories
echo "2C - Check if stick bit is set for world writable directories." >> $LOGFILE
for VAR in $WORLD_DIR
do
	#Grab the stick bit field for directories
	VAR2=$(ls -lda $VAR | head -c 10 | tail -c 1)
	if [ $VAR2 != 't' ]; then
		echo "Sticky bit for this directory $VAR is not set. It will be set." >> $LOGFILE
		chmod a+t $VAR
	else
		echo "Sticky bit for this directory $VAR is already set." >> $LOGFILE
	fi
done


echo "=== Ensure bogus ICMP responses are ignored - sysctl.conf sysctl.d (BR28) ===" >> $LOGFILE

#Check if backup file for sysctl.conf exist
echo "3A - Checking if backup file for sysctl.conf exist." >> $LOGFILE
if [ ! -f /etc/sysctl.conf.arcmc2.0.orig ]; then
	echo "3B - Backup of sysctl.conf file does not exist. Creating backup for sysctl.conf file '/etc/sysctl.conf.arcmc2.0.orig'." >> $LOGFILE
	#Backup fstab file
	cp '/etc/sysctl.conf' '/etc/sysctl.conf.arcmc2.0.orig'
else
	echo "3C - Backup of fstab file (/etc/sysctl.conf.arcmc2.0.orig) already exist." >> $LOGFILE
fi


#Check if bogus ICMP responses are ignored
echo "3D - Checking if /dev/shm line exist in /etc/fstab" >> $LOGFILE
ICMP_BOGUS_LINE=$(sed -n "/net.ipv4.icmp_ignore_bogus_error_responses/p" '/etc/sysctl.conf')

if [ ! -z "$ICMP_BOGUS_LINE" ]; then
	echo "3E - Ignore bogus ICMP responses has been added in /etc/sysctl.conf file." >> $LOGFILE
	#Delete line containing /dev/shm in fstab file
	sed -i "/net.ipv4.icmp_ignore_bogus_error_responses/d" '/etc/sysctl.conf'
	#Insert the below line in fstab file 
	echo "net.ipv4.icmp_ignore_bogus_error_responses = 1" >> '/etc/sysctl.conf'
else
	echo "3F - Ignore bogus ICMP responses is not in /etc/sysctl.conf file." >> $LOGFILE
	#Insert the below line in fstab file 
	echo "net.ipv4.icmp_ignore_bogus_error_responses = 1" >> '/etc/sysctl.conf'
fi	

#Check net.ipv4.icmp_ignore_bogus in active kernel parameters
echo "3G - Checking if /dev/shm line exist in /etc/fstab" >> $LOGFILE
SYSCTL_BOGUS_LINE=$(sysctl net.ipv4.icmp_ignore_bogus_error_responses)
if [ ! -z "$SYSCTL_BOGUS_LINE" ]; then
	VALUE=$(echo $SYSCTL_BOGUS_LINE | tail -c 2)
	if [ $VALUE == '1' ]; then
		echo "3H - ICMP bogus line already set as kernel parameter and value is 1" >> $LOGFILE
	else
		echo "3I - ICMP bogus line already set as kernel parameter but value is 0. Changing value to 1" >> $LOGFILE
		sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=1
	fi
else
	sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=1
	echo "3J - ICMP bogus line not set in kernel parameters. Setting it." >> $LOGFILE
fi

#Check if route.flush is set in active kernel parameters
SYSCTL_FLUSH_LINE=$(sysctl net.ipv4.icmp_ignore_bogus_error_responses)
if [ ! -z "$SYSCTL_FLUSH_LINE" ]; then
	VALUE=$(echo $SYSCTL_FLUSH_LINE | tail -c 2)
	if [ $VALUE == '1' ]; then
		echo "3K - Route.flush line already set as kernel parameter and value is 1" >> $LOGFILE
	else
		echo "3L - Route.flush line already set as kernel parameter but value is 0. Changing value to 1" >> $LOGFILE
		sysctl -w net.ipv4.route.flush=1
	fi
else
	echo "3M - ICMP bogus line not set in kernel parameters. Setting it." >> $LOGFILE
	sysctl -w net.ipv4.route.flush=1
fi


echo "=== Ensure permissions on all logfiles are configured (BR34)===" >> $LOGFILE

#Get all log files in the /var/log directory
VAR_LOG_FILE=$(find /var/log -type f)
if [ ! -z "$VAR_LOG_FILE" ]; then
	echo "4A - There are log files in /var/log. These are the files:" >> $LOGFILE
	echo "$VAR_LOG_FILE" >> $LOGFILE
else
	echo "4B - No log files found in /var/log." >> $LOGFILE
fi

#Check if stick bit is set for world writable directories
echo "4C - Check if stick bit is set for world writable directories." >> $LOGFILE
for VAR in $VAR_LOG_FILE
do
	#Grab the stick bit field for directories
	VAR2=$(ls -la $VAR | head -c 10 | tail -c 5)
	if [ $VAR2 != '-----' ]; then
		echo "Setting correct permission for $VAR." >> $LOGFILE
		chmod g-wx,o-rwx $VAR
	else
		echo "Correct permissions for $VAR already set." >> $LOGFILE
	fi
done



echo "=== Ensure minimum days between password changes is 7 or more (BR38)===" >> $LOGFILE

#Check if backup file for /etc/login.defs exist
echo "5A - Checking if backup file for /etc/login.defs exist." >> $LOGFILE
if [ ! -f /etc/login.defs.arcmc2.0.orig ]; then
	echo "5B - Backup of /etc/login.defs file does not exist. Creating backup for /etc/login.defs file 'login.defs.arcmc2.0.orig'." >> $LOGFILE
	#Backup login.defs file
	cp '/etc/login.defs' '/etc/login.defs.arcmc2.0.orig'
else
	echo "5C - Backup of login.defs file (/etc/login.defs.arcmc2.0.orig) already exist." >> $LOGFILE
fi

#Check if PASS_MIN_DAYS line in login.defs exist. If yes, remove it and add new PASS_MIN_DAYS line. If no, add new PASS_MIN_DAYS line.
echo "5D - Checking if PASS_MIN_DAYS line exist in /etc/login.defs" >> $LOGFILE
PASS_LINE_LOGIN=$(sed -n "/PASS_MIN_DAYS[[:space:]]*0/p" '/etc/login.defs')

if [ ! -z "$PASS_LINE_LOGIN" ]; then
	echo "5E - PASS_MIN_DAYS line in login.defs file exists. This line will be deleted and replaced with a new line." >> $LOGFILE
	#Delete line containing PASS_MIN_DAYS in login.defs file
	sed -i "/PASS_MIN_DAYS[[:space:]]*0/d" '/etc/login.defs'
	#Insert the below line in login.defs file 
	echo "PASS_MIN_DAYS   7" >> '/etc/login.defs'
else
	echo "5F - PASS_MIN_DAYS line in fstab file does not exists. It will be inserted into fstab file." >> $LOGFILE
	#Insert the below line in login.defs file 
	echo "PASS_MIN_DAYS   7" >> '/etc/login.defs'
fi	



echo "=== Add hostname entry to hosts/hostname files (DNS) ===" >> $LOGFILE

#Check if backup file for /etc/hosts exist
echo "6A - Checking if backup file for /etc/hosts exist." >> $LOGFILE
if [ ! -f /etc/hosts.orig ]; then
	echo "6B - Backup of /etc/hosts file does not exist. Creating backup for /etc/hosts file '/etc/hosts.orig'." >> $LOGFILE
	#Backup login.defs file
	cp '/etc/hosts' '/etc/hosts.orig'
else
	echo "6C - Backup of /etc/hosts file (/etc/hosts.orig) already exist." >> $LOGFILE
fi

#Add entry for Localhost Server hostname in /etc/hosts file
echo "6D - Checking if ip address line exist in /etc/hosts" >> $LOGFILE
IPADD_LINE=$(sed -n "/$HOSTNAME/p" '/etc/hosts')

if [ ! -z "$IPADD_LINE" ]; then
	echo "6E - Localhost hostname line in /etc/hosts file exists. This line will be deleted and replaced with a new line." >> $LOGFILE
	#Delete line containing Localhost Server hostname in /etc/hosts file
	sed -i "/$HOSTNAME/d" '/etc/hosts'
	#Insert the below line in /etc/hosts file
	IFS='%'
	IPADD_ENTRY="$HOSTNAMEIPADD     $HOSTNAME"
	echo "$IPADD_ENTRY" >> '/etc/hosts'
	unset IFS
else
	echo "6F - Localhost hostname line in /etc/hosts file does not exists. It will be inserted into /etc/hosts file." >> $LOGFILE
	#Insert the below line in login.defs file
	IFS='%'
	IPADD_ENTRY="$HOSTNAMEIPADD     $HOSTNAME"
	echo "$IPADD_ENTRY" >> '/etc/hosts'
	unset IFS
fi	

#Add entry for ESM Server hostname in /etc/hosts file
if [ ! -z "$ESMSERVER" ]; then
	echo "6G - Checking if ip address line exist in /etc/hosts" >> $LOGFILE
	IPADD_LINE=$(sed -n "/$ESMSERVER/p" '/etc/hosts')

	if [ ! -z "$IPADD_LINE" ]; then
		echo "6H - ESM server hostname line in /etc/hosts file exists. This line will be deleted and replaced with a new line." >> $LOGFILE
		#Delete line containing ip address in /etc/hosts file
		sed -i "/$ESMSERVER/d" '/etc/hosts'
		#Insert the below line in /etc/hosts file
		IFS='%'
		IPADD_ENTRY="$ESMIPADD     $ESMSERVER"
		echo "$IPADD_ENTRY" >> '/etc/hosts'
		unset IFS
	else
		echo "6I - ESM server hostname line in /etc/hosts file does not exists. It will be inserted into /etc/hosts file." >> $LOGFILE
		#Insert the below line in login.defs file
		IFS='%'
		IPADD_ENTRY="$ESMIPADD     $ESMSERVER"
		echo "$IPADD_ENTRY" >> '/etc/hosts'
		unset IFS
	fi	
else
	echo "6G - This is not a connector server. ESM hotname and ip address need not be inserted into /etc/hosts file." >> $LOGFILE
fi

#Add entry for Jump Server hostname in /etc/hosts file
echo "6J - Checking if ip address line exist in /etc/hosts" >> $LOGFILE
IPADD_LINE=$(sed -n "/$JUMPHOSTNAME/p" '/etc/hosts')

if [ ! -z "$IPADD_LINE" ]; then
	echo "6I - Jump server hostname line in /etc/hosts file exists. This line will be deleted and replaced with a new line." >> $LOGFILE
	#Delete line containing ip address in /etc/hosts file
	sed -i "/$JUMPHOSTNAME/d" '/etc/hosts'
	#Insert the below line in /etc/hosts file
	IFS='%'
	IPADD_ENTRY="$JUMPIPADD     $JUMPHOSTNAME"
	echo "$IPADD_ENTRY" >> '/etc/hosts'
	unset IFS
else
	echo "6K - Jump server hostname line in /etc/hosts file does not exists. It will be inserted into /etc/hosts file." >> $LOGFILE
	#Insert the below line in login.defs file
	IFS='%'
	IPADD_ENTRY="$JUMPIPADD     $JUMPHOSTNAME"
	echo "$IPADD_ENTRY" >> '/etc/hosts'
	unset IFS
fi


#Add entry for Osirium Server hostname in /etc/hosts file
echo "6L - Checking if ip address line exist in /etc/hosts" >> $LOGFILE
IPADD_LINE=$(sed -n "/$OSIRIUMSERVER/p" '/etc/hosts')

if [ ! -z "$IPADD_LINE" ]; then
	echo "6M - Osirium Server hostname line in /etc/hosts file exists. This line will be deleted and replaced with a new line." >> $LOGFILE
	#Delete line containing Osirium Server hostname in /etc/hosts file
	sed -i "/$OSIRIUMSERVER/d" '/etc/hosts'
	#Insert the below line in /etc/hosts file
	IFS='%'
	IPADD_ENTRY="$OSIRIUMIPADD     $OSIRIUMSERVER"
	echo "$IPADD_ENTRY" >> '/etc/hosts'
	unset IFS
else
	echo "6N - Osirium Server hostname line in /etc/hosts file does not exists. It will be inserted into /etc/hosts file." >> $LOGFILE
	#Insert the below line in login.defs file
	IFS='%'
	IPADD_ENTRY="$OSIRIUMIPADD     $OSIRIUMSERVER"
	echo "$IPADD_ENTRY" >> '/etc/hosts'
	unset IFS
fi

#Add entry for Localhost Server in /etc/hosts file
echo "6O - Checking if Localhost Server line exist in /etc/sysconfig/network file" >> $LOGFILE

IPADD_LINE=$(sed -n "/$HOSTNAME/p" '/etc/sysconfig/network')

if [ ! -z "$IPADD_LINE" ]; then
	echo "6P - Localhost Server line in /etc/sysconfig/network file exists. This line will be deleted and replaced with a new line." >> $LOGFILE
	#Delete line containing ip address in /etc/hosts file
	sed -i "/$HOSTNAME/d" '/etc/sysconfig/network'
	#Insert the below line in /etc/sysconfig/network file
	IFS='%'
	IPADD_ENTRY="$HOSTNAMEIPADD     $HOSTNAME"
	echo "$IPADD_ENTRY" >> '/etc/sysconfig/network'
	unset IFS
else
	echo "6Q - Localhost Server line in /etc/sysconfig/network file does not exists. It will be inserted into /etc/sysconfig/network file." >> $LOGFILE
	#Insert the below line in /etc/sysconfig/network file
	IFS='%'
	IPADD_ENTRY="$HOSTNAMEIPADD     $HOSTNAME"
	echo "$IPADD_ENTRY" >> '/etc/sysconfig/network'
	unset IFS
fi

#Set hostname on console
echo "6R - Setting hostname to $LOWERHOSTNAME" >> $LOGFILE
LOWERHOSTNAME=$(echo "$HOSTNAME" | tr '[:upper:]' '[:lower:]')
hostnamectl set-hostname "$LOWERHOSTNAME"
echo "6S - Restarting systemd-hostnamed and network" >> $LOGFILE
systemctl restart systemd-hostnamed
systemctl restart network



echo "=== Install packages (YUM/RPM) ===" >> $LOGFILE

#Stop iptables
echo "7A - Stopping iptables" >> $LOGFILE
service iptables stop
#Stop SE Linux
echo "7B - Setting SE Linux to permissive" >> $LOGFILE
setenforce 0

#Interate through package list
for index in "${PACKAGESARRAY[@]}"; do
	#Find if package is installed using RPM
	installed=$(rpm -qa | grep "$index")
	#If package is not installed, install it
	if [ -z "$installed" ]; then
		echo "7C - Package $installed is not installed. This package will be installed" >> $LOGFILE
		yum -y install "$index"
	#If package is installed, do nothing
	else
		echo "7D - Package $installed is already installed." >> $LOGFILE
	fi
done

#Start iptables
echo "7E - Starting iptables." >> $LOGFILE
service iptables start
#Start SE Linux
echo "7E - Setting SE Linux to enforcing." >> $LOGFILE
setenforce 1



echo "=== Add IP Address to /etc/ntp.conf ===" >> $LOGFILE

#Check if backup file for /etc/ntp.conf exist
echo "8A - Checking if backup file for /etc/ntp.conf exist." >> $LOGFILE
if [ ! -f /etc/ntp.conf.orig ]; then
	echo "8B - Backup of /etc/ntp.conf file does not exist. Creating backup for /etc/ntp.conf file 'ntp.conf.orig'." >> $LOGFILE
	#Backup login.defs file
	cp '/etc/ntp.conf' '/etc/ntp.conf.orig'
else
	echo "8C - Backup of /etc/ntp.conf file (/etc/ntp.conf.orig) already exist." >> $LOGFILE
fi

#Interate through remove ntp servers list
for index in "${NTPREMOVESERVERS[@]}"; do
	#Find if ntp server line is in /etc/ntp.conf
	isin=$(sed -n "/$index/p" '/etc/ntp.conf')
	#If ntp server is in file, remove it
	if [ ! -z "$isin" ]; then
		echo "7D - $index line is in /etc/ntp.conf file. This line will be removed." >> $LOGFILE
		sed -i "/$index/d" '/etc/ntp.conf'
	#If ntp server is not in file, do nothing
	else
		echo "7E - $index line is not in /etc/ntp.conf file." >> $LOGFILE
	fi
done

#Insert intended ntp server into file
echo "server $NTPIPADD iburst" >> '/etc/ntp.conf'
#Restarting ntpd
service ntpd restart


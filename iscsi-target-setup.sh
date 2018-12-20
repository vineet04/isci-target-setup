#!/bin/bash


##########################################
#Script to set up Iscsi target connection#
#Created by: Vineet Sinha                #
#Date:5th Jun2016                       #    
#########################################

#Variables

COUNTER=0
IPAddr=$2
BLOCK=$1

if [ $# -eq 0 ]
   
   then echo -e "\t \t \n \n Arguments missing. type -h or --help for usage \n"
   exit
elif [ "$1" == "-h" ] || [ "$1" == "--help" ]
   then echo "usage: iscsi-target-setup.sh [-h] [arg]
        where 
        -h, --help show this help text
        arg1 specify number of backstore to configure
        arg2 specify number of ip addresses"
exit
fi

#Check targetcli is installed

echo -e "\t \n\n ##### Checking if targetcli is installed ##### \n"

rpm -qa |grep -i targetcli | cut -d - -f1 > /dev/null

if [ $? -eq 0 ]; then echo -e " \n\n ##### Targetcli is installed ###### \n";

else yum install -y -q targetcli; systemctl start target; systemctl enable target

fi

# Check file is contains initiator name of all clients

if [ -f /etc/iscsi/initiatorname.iscsi ]; then

echo -e "\t \t \n \n Reading file to verify all clients initiator name are there in /etc/iscsi/initiatorname.iscsi, else exit script and update it!! \t \n ";
cat /etc/iscsi/initiatorname.iscsi;

fi 

#  Setup a backstores using LVM

if [ -f /tmp/lvs ]; then
cat /dev/null > /tmp/lvs 2>&1
fi

while [ "$1" -ne 0 ] && [ $COUNTER -lt $BLOCK ]; do

echo -e " \t \t \n \n Enter Logical volume to be used, ensure relevant lv is already created or else create one and run script again\t \n ."
read -p " LV :"
lvs --noheadings $LV|awk '{print $1}' >> /tmp/lvs 2>&1
for i in `cat /tmp/lvs`
do
targetcli /backstores/block create $i $LV
done

#targetcli /backstores/block create block$BLOCK $LV

((BLOCK--))

done

########     Setup Iscsitarget connection #########

#######################################################
# rfc3721.txt explains naming convention of iqn       #
#- 1.1.  Constructing iSCSI names using the iqn.format#
####################################################### 

echo -e " \t\t \n \n Enter target iqn:use format as iqn.yyyy-mm.com.example:connectionX \n "
read IQN  
echo $IQN
targetcli /iscsi set global auto_add_default_portal=false; targetcli /iscsi set global auto_cd_after_create=false; targetcli /iscsi create $IQN; 

while [ "$2" -ne 0 ] && [ $COUNTER -lt $IPAddr ];do

# Setup portals
echo -e "\t\t \n \n #### Enter a IP address #### \n"
read -p "IP :"
targetcli /iscsi/$IQN/tpg1/portals create $IP

((IPAddr--))

done

# Setup lun


#for i in `targetcli ls /backstores/block/  | awk '{print $2}' |grep -v "-" |egrep -v "block|alua|default_tg_pt_gp"`; do targetcli /iscsi/$IQN/tpg1/luns create /backstores/block/$i;done 

for i in `cat /tmp/lvs`;do targetcli /iscsi/$IQN/tpg1/luns create /backstores/block/$i;done 

# Setup acl
for i  in `cat /etc/iscsi/initiatorname.iscsi | grep -i iqn | cut -d = -f2`; do targetcli /iscsi/$IQN/tpg1/acls create $i; done

#Print target session and exit

targetcli ls;exit

#!/bin/bash
# based on code byLeon Mergen
# see: https://leonmergen.com/automatically-mounting-instance-store-on-an-aws-ami-150da3ffd041

LVDISPLAY="/sbin/lvdisplay"  
PVCREATE="/sbin/pvcreate"  
VGCREATE="/sbin/vgcreate"  
LVCREATE="/sbin/lvcreate"  
MKFS="/sbin/mkfs -t xfs" 
MOUNTPOINT="/mnt/data" 
DEVICE_PREFIX="/dev/"

if [[ -b /dev/dm-0 ]] ; then	
	echo "LVM already configured, exiting ...."	
	exit 3
fi

function mount_volume { 
if [ ! -f "$MOUNTPOINT" ]
then	
	mkdir -p ${MOUNTPOINT}
fi
echo "mounting: $1 => ${MOUNTPOINT}" 
mount $1 ${MOUNTPOINT} 
}

# Detects all local block devices present on the machine,
# skipping the first (which is assumed to be root). 
function detect_devices { 
	
	local PREFIX=$1	
	for x in  $(curl -s http://169.254.169.254/latest/meta-data/block-device-mapping/ | grep ephemeral) 	
	do	
		if [ $x == 0 ] ; then	
			echo "No ephemeral devices found, exiting ...." 	
			exit 4	
		fi
		
		# Get device mapping
		DEVICE="${PREFIX}$(curl -s http://169.254.169.254/latest/meta-data/block-device-mapping/$x)"	
		# Verify that this device is not in use	using the actuall device name	
		
		if ! grep -q $(readlink -f ${DEVICE}) /proc/mounts	
		then	
			# Verify that this is a block device	
			if [[ -b ${DEVICE} ]]	
			then 	
		    echo "${DEVICE}" 	
			fi	
		else
			# Exit if the only device is alread in use
			if [ $x == 1 ] ; then	
				echo "Ephemeral device already in use, exiting ...." 	
				exit 5	
			fi	
		fi	  	
	done 
} 

# Creates a new LVM volume. Accepts an array of block devices to 
# use as physical storage. 
function create_volume { 	
	for device in $@ 	
	do	
		echo ${PVCREATE} ${device}	
	  ${PVCREATE} ${device} 	
	done 
	
	# Creates a new volume group called 'data' which pools all 	
	# available block devices. 	
	echo ${VGCREATE} data $@ 	
	${VGCREATE} data $@ 
	
	# Create a logical volume with all the available storage space 	
	# assigned to it. 	
	echo ${LVCREATE} -l 100%FREE data	
	${LVCREATE} -l 100%FREE data 
	
	# Create a filesystem so we can use the partition. 	
	echo ${MKFS} $(get_volume) 	
	${MKFS} $(get_volume) 
} 

function detect_volume { 	
	echo $(${LVDISPLAY} | grep 'LV Path' | awk '{print $3}') 
} 

# Similar to detect_volume, but fails if no volume is found. 
function get_volume { 	
	local VOLUME=$(detect_volume) 	
	if [[ -z ${VOLUME} ]] 	
	then 	
	  echo "Fatal error: LVM volume not found!" 1>&2 	
	  exit 1 	
	fi 	
	echo $VOLUME 
} 

# Detect existing LVM volume 
VOLUME=$(detect_volume) 

# And create a brand new LVM volume if none were found 
if [[ -z ${VOLUME} ]] 
then 	
	create_volume $(detect_devices ${DEVICE_PREFIX}) 
fi 

mount_volume $(get_volume)

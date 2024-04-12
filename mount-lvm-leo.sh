1 #!/usr/bin/env bash  
 2  
 3 LVDISPLAY="/sbin/lvdisplay"  
 4 PVCREATE="/sbin/pvcreate"  
 5 VGCREATE="/sbin/vgcreate"  
 6 LVCREATE="/sbin/lvcreate"  
 7  
 8  
 9 DEVICE_PREFIX="/dev/xvd" 
10 MKFS="/sbin/mkfs -t ext4" 
11 MOUNTPOINT="/mnt/data" 
12 
13 function mount_volume { 
14 echo "mounting: $1 => ${MOUNTPOINT}" 
15 mount $1 ${MOUNTPOINT} 
16 } 
17 
18 # Detects all local block devices present on the machine,
19 # skipping the first (which is assumed to be root). 
20 function detect_devices { 
21   local PREFIX=$1 
22   for x in {b..z} 
23   do 
24     DEVICE="${PREFIX}${x}" 
25     if [[ -b ${DEVICE} ]] 
26     then 
27       echo "${DEVICE}" 
28     fi 
29   done 
30 } 
31 
32 # Creates a new LVM volume. Accepts an array of block devices to 
33 # use as physical storage. 
34 function create_volume { 
35   for device in $@ 
36   do 
37     ${PVCREATE} ${device} 
38   done 
39 
40   # Creates a new volume group called 'data' which pools all 
41   # available block devices. 
42   ${VGCREATE} data $@ 
43 
44   # Create a logical volume with all the available storage space 
45   # assigned to it. 
46   ${LVCREATE} -l 100%FREE data 
47 
48   # Create a filesystem so we can use the partition. 
49   ${MKFS} $(get_volume) 
50 } 
51 
52 function detect_volume { 
53   echo $(${LVDISPLAY} | grep 'LV Path' | awk '{print $3}') 
54 } 
55 
56 # Similar to detect_volume, but fails if no volume is found. 
57 function get_volume { 
58   local VOLUME=$(detect_volume) 
59   if [[ -z ${VOLUME} ]] 
60   then 
61     echo "Fatal error: LVM volume not found!" 1>&2 
62     exit 1 
63   fi 
64   echo $VOLUME 
65 } 
66 
67 # Detect existing LVM volume 
68 VOLUME=$(detect_volume) 
69 
70 # And create a brand new LVM volume if none were found 
71 if [[ -z ${VOLUME} ]] 
72 then 
73   create_volume $(detect_devices ${DEVICE_PREFIX}) 
74 fi 
75 
76 mount_volume $(get_volume)

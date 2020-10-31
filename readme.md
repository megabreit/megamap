# Megamap.pl will display disk slot to device name mappings with MegaRAID adapters

This was tested with SLES 12 and RHEL7 with Cisco MegaRAID 12G = LSI MegaRAID SAS 3108, other adapters might also work.
You need root permissions to run this script!

# Prerequisites
- perl 5.x
- storcli-1.21.06-1.noarch is required. No other versions were tested but might work too.
- sg3_utils package needs to be installed.
- The script works out of the box with SLES >=12. On RHEL 7.x the udev rule file need to be added to /etc/udev/rules.d.

Redhat promised to add those udev rule to RHEL 8.x, this still needs to be verified.

The script is work in progress... feel free to contact the author if you notices problems, bugs etc. or want to contribute.

```
Usage: megamap.pl [-h] [-V] [-l | -d | -s] [device, location or slot name}
  -h      display this help
  -V      display version
  -d      list all devices by device name (sdX)
  -l      list all devices by MegaRAID drive location name
  -s      list all devices by slot name (sX)
  -d sdX  list specified device by device name (sdX)
  -s sX   list specified device by slot name (sX)
  -l /cX/eY/sZ | /cX/vY     list specified device by MegaRAID drive location name

 -s assumes that there is only ONE controller present! Currently, this is intentional :-)
```
# Examples:

#### Show all disk devices (4 JBODs and 2 RAIDs)
```
#megamap.pl -d
#Dev Location      Type    State Smart WWN                              RAID-Members
sda  /c0/e8/s6     JBOD    JBOD  No    5000C5008619AF90                 -
sdb  /c0/e8/s8     JBOD    JBOD  No    5000C500861B2F2C                 -
sdc  /c0/e8/s7     JBOD    JBOD  No    5000C500861B692C                 -
sdd  /c0/e8/s5     JBOD    JBOD  No    5000C500861B7068                 -
sde  /c0/v0        RAID1   Optl  -     6006bf1d58d410802078dd9c38c221e0 /c0/e8/s3 /c0/e8/s4
sdf  /c0/v1        RAID1   Optl  -     6006bf1d58d410802078dda13914543d /c0/e8/s1 /c0/e8/s2
```

#### Show all adapter locations including slots (4 JBODs, 2 RAIDs and 2 virtual arrays)
```
#megamap.pl -l
#Location     Dev  Type        State Smart RAID      Device-by-path
/c0/v0        sde  RAID1       Optl  -     -         disk/by-path/pci-0000:08:00.0-scsi-0:2:0:0
/c0/v1        sdf  RAID1       Optl  -     -         disk/by-path/pci-0000:08:00.0-scsi-0:2:1:0
/c0/e8/s1     -    RAID-Member Onln  No    /c0/v1    -
/c0/e8/s2     -    RAID-Member Onln  No    /c0/v1    -
/c0/e8/s3     -    RAID-Member Onln  No    /c0/v0    -
/c0/e8/s4     -    RAID-Member Onln  No    /c0/v0    -
/c0/e8/s5     sdd  JBOD        JBOD  No    -         disk/by-path/pci-0000:08:00.0-scsi-0:0:16:0
/c0/e8/s6     sda  JBOD        JBOD  No    -         disk/by-path/pci-0000:08:00.0-scsi-0:0:9:0
/c0/e8/s7     sdc  JBOD        JBOD  No    -         disk/by-path/pci-0000:08:00.0-scsi-0:0:13:0
/c0/e8/s8     sdb  JBOD        JBOD  No    -         disk/by-path/pci-0000:08:00.0-scsi-0:0:12:0
```
#### Show all slots (locations without controller, enclosure or virtual adapter info).
These slots map directly to the slot numbers of the Cisco host.
```
#megamap.pl -s
#Slot No. Location      Dev  Type        State Smart RAID      Device-by-path
-     -   /c0/v0        sde  RAID1       Optl  -     -         disk/by-path/pci-0000:08:00.0-scsi-0:2:0:0
-     -   /c0/v1        sdf  RAID1       Optl  -     -         disk/by-path/pci-0000:08:00.0-scsi-0:2:1:0
s1    1   /c0/e8/s1     -    RAID-Member Onln  No    /c0/v1    -
s2    2   /c0/e8/s2     -    RAID-Member Onln  No    /c0/v1    -
s3    3   /c0/e8/s3     -    RAID-Member Onln  No    /c0/v0    -
s4    4   /c0/e8/s4     -    RAID-Member Onln  No    /c0/v0    -
s5    5   /c0/e8/s5     sdd  JBOD        JBOD  No    -         disk/by-path/pci-0000:08:00.0-scsi-0:0:16:0
s6    6   /c0/e8/s6     sda  JBOD        JBOD  No    -         disk/by-path/pci-0000:08:00.0-scsi-0:0:9:0
s7    7   /c0/e8/s7     sdc  JBOD        JBOD  No    -         disk/by-path/pci-0000:08:00.0-scsi-0:0:13:0
s8    8   /c0/e8/s8     sdb  JBOD        JBOD  No    -         disk/by-path/pci-0000:08:00.0-scsi-0:0:12:0
```
#### Show device file for a specific slot
```
#megamap.pl -s s8
disk/by-path/pci-0000:08:00.0-scsi-0:0:12:0
```
#### Show location for a specific device (virtual array)
```
#megamap.pl -d sde
/c0/v0
```
#### Show location for a specific device (JBOD)
```
#megamap.pl -d sda
/c0/e8/s6
```
#### Show device for a specific location (virtual array)
```
#megamap.pl -l /c0/v0
sde
```
#### Show device for a specific location (JBOD)
```
#megamap.pl -l /c0/e8/s6
sda
```
#### Show location and RAID5 members
```
#megamap.pl -d
#Dev Location      Type    State Smart WWN                              RAID-Members
sda  /c0/v0        RAID5   Optl  -     6006bf1d58d40a902078bfbc105f57ab /c0/e8/s1 /c0/e8/s2 /c0/e8/s3 /c0/e8/s4 /c0/e8/s5 /c0/e8/s6 /c0/e8/s7 /c0/e8/s8
```
#### Show all locations for all disk connected to the raid controller
RAID members have a slot but no device
```
#megamap.pl -l
#Location     Dev  Type        State Smart RAID      Device-by-path
/c0/v0        sda  RAID5       Optl  -     -         disk/by-path/pci-0000:08:00.0-scsi-0:2:0:0
/c0/e8/s1     -    RAID-Member Onln  No    /c0/v0    -
/c0/e8/s2     -    RAID-Member Onln  No    /c0/v0    -
/c0/e8/s3     -    RAID-Member Onln  No    /c0/v0    -
/c0/e8/s4     -    RAID-Member Onln  No    /c0/v0    -
/c0/e8/s5     -    RAID-Member Onln  No    /c0/v0    -
/c0/e8/s6     -    RAID-Member Onln  No    /c0/v0    -
/c0/e8/s7     -    RAID-Member Onln  No    /c0/v0    -
/c0/e8/s8     -    RAID-Member Onln  No    /c0/v0    -
```
#### Show all slot numbers for all disks connected to the raid controller
Virtual controllers have a device but not slot
```
#megamap.pl -s
#Slot No. Location      Dev  Type        State Smart RAID      Device-by-path
-     -   /c0/v0        sda  RAID5       Optl  -     -         disk/by-path/pci-0000:08:00.0-scsi-0:2:0:0
s1    1   /c0/e8/s1     -    RAID-Member Onln  No    /c0/v0    -
s2    2   /c0/e8/s2     -    RAID-Member Onln  No    /c0/v0    -
s3    3   /c0/e8/s3     -    RAID-Member Onln  No    /c0/v0    -
s4    4   /c0/e8/s4     -    RAID-Member Onln  No    /c0/v0    -
s5    5   /c0/e8/s5     -    RAID-Member Onln  No    /c0/v0    -
s6    6   /c0/e8/s6     -    RAID-Member Onln  No    /c0/v0    -
s7    7   /c0/e8/s7     -    RAID-Member Onln  No    /c0/v0    -
s8    8   /c0/e8/s8     -    RAID-Member Onln  No    /c0/v0    -
```
#### When a disk is a raid member, no device is shown.
```
# megamap.pl -l /c0/e8/s4
# 
```

# Output Columns
| Name | Meaning|
| ---      |  ------  |
| Dev | disk device name, e.g. sda, sdb|
| Location | location description from the MegaRaid adapter, e.g /c0/e1/s1 for physical disks or /c0/v0 for virtual arrays|
| Slot | location with the controller and enclosure part stripped. Only physical disks (JBOD) hava a slot!|
| No. | slot number without the "s", for convenience only|
| Type | disk type of this device, e.g RAIS015, RAID-Member, JBOD|
| State | device state, e.g. Optl (Optimal), Onln (Online), see storcli for detail|
| Smart | Smart check of this device shows isues, only for JBODs|
| RAID | location name of virtual array|
| Device-by-path | device name in /dev/disk/by-path|
| WWN | WWN of the disk, virtual arrays have a generated WWN|
| RAID-Members | location names of all RAID members|

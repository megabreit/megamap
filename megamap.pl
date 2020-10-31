#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;

my $megamap_version="1.2";

sub usage {
        print STDERR "Usage: $0 [-h] [-V] [-l | -d | -s] [device, location or slot name}\n";
        print STDERR "  -h      display this help\n";
        print STDERR "  -V      display version\n";
        print STDERR "  -d      list all devices by device name (sdX)\n";
        print STDERR "  -l      list all devices by MegaRAID drive location name\n";
        print STDERR "  -s      list all devices by slot name (sX)\n";
        print STDERR "  -d sdX  list specified device by device name (sdX)\n";
        print STDERR "  -s sX   list specified device by slot name (sX)\n";
        print STDERR "  -l /cX/eY/sZ | /cX/vY     list specified device by MegaRAID drive location name\n\n";
        print STDERR " -s assumes that there is only ONE controller present! Currently, this is intentional :-)\n";
        exit 1;
}

# subroutine to sort the megaraid device locations numerically rather than alphabetically
sub megaraid_slot_numerically {
	# extract numbers from /cY/eY/sZ and /cX/vY and compare numerically
	#$a=~ /\/c(\d+)\/(?:v|e)(\d+)(?:\/s(\d+)){0,1}/;
	#my $aa="$1$2"; if ( defined $3 ) { $aa="$aa$3"; }
	#$b=~ /\/c(\d+)\/(?:v|e)(\d+)(?:\/s(\d+)){0,1}/;
	#my $bb="$1$2"; if ( defined $3 ) { $bb="$bb$3"; }
	my $aa = join( "", split( /\D+/, $a)); # remove any non-digit
	my $bb = join( "", split( /\D+/, $b)); # remove any non-digit
	return $aa <=> $bb;
}

my %options;

GetOptions( 	"d:s"	=> \$options{'devices'},
		"l:s"	=> \$options{'locations'},
		"s:s"	=> \$options{'slots'},
		"V"	=> \$options{'version'},
		"h"	=> \$options{'help'},
        ) or usage;

if ( $options{'help'} ) { usage; };

# show one line with version information
if ( $options{'version'} ) {
        print "megamap version $megamap_version\n";
        exit 0;
}

# default action -> show help
if ( ! defined $options{'devices'} && ! defined $options{'locations'} && ! defined $options{'slots'} && ! defined $options{'version'} ) {
	usage;
}

# don't allow -d and -l at the same time
if ( ( defined $options{'devices'} && defined $options{'locations'} ) ||
     ( defined $options{'devices'} && defined $options{'slots'} ) ||
     ( defined $options{'slots'} && defined $options{'locations'} ) ) {
	usage;
}

# print Data::Dumper->Dump([ \%options ], [ qw(*options) ]);

# check for root permissions, storcli needs them
if ( $< != 0 ) {
	print STDERR "You need to be root to run this script!\n";
	exit 1;
}
my %disks;

my @scsi_devices= glob ("/dev/sd*[a-z]");	# just the SCSI disk devices, no partitions

#print "@scsi_devices\n";

# the all-in-one command for us is storcli64 /call/eall/sall show all
# this will list controllers and disks like /c0/e8/s1 and all necessary attributes

my $storinfo=qx{ /opt/MegaRAID/storcli/storcli64 /call/eall/sall show all };
# TODO check for "^Status = Success$" in output (2nd line)
# seems to be one block for each controller, can there be mixed status values???

#print $storinfo;

my %drive_by_wwn;
my %drive_by_location;
my %drive_by_slot;
my $skip_first_line = 0;
# split at line "Drive /c0/e8/s1 :"
foreach my $block ( split( /^Drive\s+\/c\d+\/e\d+\/s\d+\s+:$/m, $storinfo )) {
	next if not $skip_first_line++; # skip junk before first entry

	#print $block;

	my $enclosure="";
	my $slot="";
	my $location; my $wwn;
	if ( $block =~ /^Drive\s+(\/c\d+\/e\d+\/s\d+)\s+State.*S.M.A.R.T alert flagged by drive = (\S+).*SN = (\S+).*WWN = (\S+)/ms ) {

		$drive_by_wwn{$4}->{'wwn'}=$4;
		$drive_by_wwn{$4}->{'location'}=$1;
		$drive_by_wwn{$4}->{'smart_alert'}=$2;
		$drive_by_wwn{$4}->{'serial'}=$3;

		$drive_by_location{$1}->{'location'}=$1;
		$drive_by_location{$1}->{'wwn'}=$4;
		$drive_by_location{$1}->{'smart_alert'}=$2;
		$drive_by_location{$1}->{'serial'}=$3;

		$location=$1;
		$wwn=$4;

		( my $dummy1 , my $dummy2,  $enclosure, $slot ) = split ( /\/\S/, $location );
	}
	if ( $block =~ /^$enclosure:$slot\s+\S+\s+(\S+)/ms ) {
		$drive_by_wwn{$wwn}->{'state'}=$1;
		$drive_by_location{$location}->{'state'}=$1;
		$drive_by_location{$location}->{'slot_number'}=$slot;
		$drive_by_location{$location}->{'slot'}="s".$slot;
		$drive_by_slot{"s".$slot}->{'location'}=$drive_by_location{$location}->{'location'};
		$drive_by_wwn{$wwn}->{'type'}=$1 eq "JBOD"? "JBOD":"RAID-Member";
		$drive_by_location{$location}->{'type'}=$1 eq "JBOD"? "JBOD":"RAID-Member";
	}
}

# print Data::Dumper->Dump([ \%drive_by_wwn ], [ qw(*drive_by_wwn) ]);

# storcli64 /cx/v0 will show NAA id of the raid array (/call/vall will display all raids on all controllers)
# SCSI NAA Id = 6006bf1d58d410802078dd9c38c221e0
# matching udevadm info -q all -n... output:
# E: ID_WWN=0x6006bf1d58d410802078dd9c38c221e0

my $raidinfo=qx{ /opt/MegaRAID/storcli/storcli64 /call/vall show all };
# TODO check for "^Status = Success$" in output (2nd line)
# seems to be one block for each controller, can there be mixed status values???


my $current_device="";
my $current_controller="";
my $current_wwn;
$skip_first_line = 0;

foreach my $block ( split( /^(\/c\d+\/v\d+)\s+:/m, $raidinfo ) ) {
	next if not $skip_first_line++; # skip junk before first entry

	# split creates 2 blocks, first has only /x/vx, second has matching info
	if ( $block =~ /^\/c(\d+)\/v\d+$/ ) {
		# 1. block
		$current_device=$block;
		$current_controller=$1;
		next;
	}
	if ( $current_device ne "" ) {
		# 2. block
		#print "$current_device\n";

		# Exposed to OS = Yes
		# ..
		# SCSI NAA Id = 6006bf1d58d410802078dda13914543d
		if ( $block =~ /Exposed to OS = Yes.*SCSI NAA Id = (\S+)/ms ) {
			$drive_by_wwn{$1}->{'wwn'}=$1;
			$drive_by_wwn{$1}->{'location'}=$current_device;
			$drive_by_location{$current_device}->{'location'}=$current_device;
			$drive_by_location{$current_device}->{'wwn'}=$1;
			$current_wwn=$1; # for next blocks
		}
		# get RAID type and RAID state
		if ( $block =~ /^DG\/VD\s+TYPE\s+State\s+Access\s+Consist\s+Cache\s+Cac\s+sCC\s+Size\s+Name\s+\n-+\n\S+\s+(\S+)\s+(\S+)/ms ) {
			$drive_by_wwn{$current_wwn}->{'type'}=$1;
			$drive_by_wwn{$current_wwn}->{'state'}=$2;
			$drive_by_location{$current_device}->{'type'}=$1;
			$drive_by_location{$current_device}->{'state'}=$2;
		}
		# PDs for VD 0 :
		# ============
		# 
		# ----------------------------------------------------------------------------
		# EID:Slt DID State DG     Size Intf Med SED PI SeSz Model            Sp Type 
		# ----------------------------------------------------------------------------
		# 8:1      11 Onln   0 1.089 TB SAS  HDD N   N  512B ST1200MM0088     U  -    
		# 8:2      16 Onln   0 1.089 TB SAS  HDD N   N  512B ST1200MM0088     U  -    
		# 8:3       9 Onln   0 1.089 TB SAS  HDD N   N  512B ST1200MM0088     U  -    
		# 8:4      10 Onln   0 1.089 TB SAS  HDD N   N  512B ST1200MM0088     U  -    
		# 8:5      12 Onln   0 1.089 TB SAS  HDD N   N  512B ST1200MM0088     U  -    
		# 8:6      13 Onln   0 1.089 TB SAS  HDD N   N  512B ST1200MM0088     U  -    
		# 8:7      14 Onln   0 1.089 TB SAS  HDD N   N  512B ST1200MM0088     U  -    
		# 8:8      15 Onln   0 1.089 TB SAS  HDD N   N  512B ST1200MM0088     U  -    
		# ----------------------------------------------------------------------------
		#
		my @raidmembers = split( /PDs for VD.*EID:Slt\s+DID\s+State\s+DG\s+Size\s+Intf\s+Med\s+SED\s+PI\s+SeSz\s+Model\s+Sp\s+Type\s+\n-+\n/ms, $block );
		shift ( @raidmembers ); # remove leading garbage
		# @raidmembers contains now all disk lines and following
		my @lines = split ( /\n/, shift @raidmembers );

		foreach my $raid_device ( @lines ) {
			last if ( $raid_device =~ /^-/ ); #skip lines after last ----
			if ( $raid_device =~ /(\d+):(\d+)\s+\S+\s+(\S+)\s+\S+\s+(\S+\s+\S+)/ ) {
				my $current_location="/c$current_controller/e$1/s$2";
				push ( @{$drive_by_wwn{$current_wwn}->{'members'}}, $current_location);
				$drive_by_location{$current_location}->{'member_of_raid'}=$current_device;
				
			}
		}
		$current_device="";

	}
}

# print Data::Dumper->Dump([ \%drive_by_wwn ], [ qw(*drive_by_wwn) ]);
# print Data::Dumper->Dump([ \%drive_by_location ], [ qw(*drive_by_location) ]);
# print Data::Dumper->Dump([ \%drive_by_slot ], [ qw(*drive_by_slot) ]);

foreach my $device ( @scsi_devices ) {
	my $udevinfo=qx{ /sbin/udevadm info -q all -n $device };
	# TODO: Error check

	my $name;
	if ( $udevinfo =~ /N:\s+(\S+).*(E:\s+SCSI_IDENT_TARGET_NAME=naa.(?<wwn>\S+)|E:\s+SCSI_IDENT_LUN_NAA_REGEXT=(?<wwn>\S+))/sm ) {
		next if ( ! defined $drive_by_wwn{$+{wwn}} ); # skip non-Megaraid disks
		$disks{$1}->{'name'}=$1;
		$disks{$1}->{'wwn'}=$+{wwn}; # using named capture group here to simplify the match, see (?<wwn>...) above!
		# get all the device names
		my @lines= split( /\n/, $udevinfo ); # convert to list for easier greping
		my @devicenames = grep ( /^S:/, @lines );
		foreach my $dev ( @devicenames ) {
			my ( $garbage, $devname ) = split ( /\s+/, $dev );
			#print "found $devname\n";
			push ( @{$disks{$1}->{'device_aliases'}}, $devname );
		}
	}
	# we look for:
	# N: sdn
	# S: disk/by-id/scsi-35000c500998e8717
	# S: disk/by-id/scsi-SSEAGATE_ST1800MM0008_S3Z0YP560000E7220LJ5
	# S: disk/by-id/wwn-0x5000c500998e8717
	# S: disk/by-path/pci-0000:08:00.0-scsi-0:0:20:0

	# E: SCSI_IDENT_TARGET_NAME=naa.5000C500998E8714

	# ignore device when E: ID_BUS=ata
	# SSDs don't have SCSI_IDENT_TARGET_NAME

	# raid disks on megaraid controllers use other WWNs:
	# E: SCSI_IDENT_LUN_NAA_REGEXT=6006bf1d58d40a902078bfbc105f57ab
	# other variables contain the same information... not sure what's the right info

}

#print Data::Dumper->Dump([ \%disks ], [ qw(*disks) ]);

# Now complete the various missing information in all hashes

# add device names to wwn hash
foreach my $drive ( keys %drive_by_wwn ) {
	foreach my $disk ( keys %disks ) {
		if ( $drive_by_wwn{$drive}->{'wwn'} eq $disks{$disk}->{'wwn'} ) {
			$drive_by_wwn{$drive}->{'device'}=$disk;
			# put location into disks hash
			$disks{$disk}->{'location'} = $drive_by_wwn{$drive}->{'location'};
			last;
		}
	}
}

#print Data::Dumper->Dump([ \%drive_by_wwn ], [ qw(*drive_by_wwn) ]);
#print Data::Dumper->Dump([ \%disks ], [ qw(*disks) ]);

# add device names to location hash too for later convenience
foreach my $loc ( keys %drive_by_location ) {
	if ( defined $drive_by_location{$loc}->{'wwn'} && defined $drive_by_wwn{$drive_by_location{$loc}->{'wwn'}}->{'wwn'} &&
		defined $drive_by_wwn{$drive_by_location{$loc}->{'wwn'}}->{'device'} ) {
		$drive_by_location{$loc}->{'device'} = $drive_by_wwn{$drive_by_location{$loc}->{'wwn'}}->{'device'};
	}
}

#print Data::Dumper->Dump([ \%drive_by_location ], [ qw(*drive_by_location) ]);

if ( defined $options{'devices'} ) {
	if ( $options{'devices'} eq "" ) {
		# device name (sdX), location name (/cX/eY/sZ or /cX/vY),  device type, device state, device smart alert (if avail), wwn/naa, raid members (if any)
		printf("%-4s %-13s %-7s %-5s %-5s %-32s %s\n","#Dev","Location","Type","State","Smart","WWN","RAID-Members");
		foreach my $disk ( sort keys %disks ) {
			next if ( ! defined $disks{$disk}->{'wwn'} ); # print no disks without wwn's
			next if ( ! defined $drive_by_wwn{$disks{$disk}->{'wwn'}} ); # ..and no disks not coming from the megaraid controller
			my $device=$disks{$disk}->{'wwn'};
			if ( defined $drive_by_wwn{$device}->{"device"} ) {
				printf("%-4s %-13s %-7s %-5s %-5s %-32s %s\n",
					$drive_by_wwn{$device}->{"device"},
					$drive_by_wwn{$device}->{"location"},
					$drive_by_wwn{$device}->{"type"},
					$drive_by_wwn{$device}->{"state"},
					defined $drive_by_wwn{$device}->{"smart_alert"} ? $drive_by_wwn{$device}->{"smart_alert"} : "-",
					$drive_by_wwn{$device}->{"wwn"},
					defined $drive_by_wwn{$device}->{"members"} ? join(" ", map {sprintf "%s",$_} @{$drive_by_wwn{$device}->{"members"}} ) : "-"
					);
			}
		}
	} else {
		if ( defined $disks{$options{'devices'}}->{"location"} ) {
			printf("%s\n", $disks{$options{'devices'}}->{"location"});
		} else {
			exit 1;
		}
	}
} elsif ( defined $options{'locations'} ) {
	if ( $options{'locations'} eq "" ) {
		# location name (/cX/eY/sZ), device type, device state, device smart state (if avail), device name (sdX if avail), raid name (/cX/vY), long device name (by-path if avail)
		printf("%-13s %-4s %-11s %-5s %-5s %-9s %s\n","#Location","Dev","Type","State","Smart","RAID","Device-by-path");
		foreach my $loc ( sort megaraid_slot_numerically keys %drive_by_location ) {
			printf("%-13s %-4s %-11s %-5s %-5s %-9s %s\n",
				$loc,
				defined $drive_by_location{$loc}->{"device"} ? $drive_by_location{$loc}->{"device"} : "-",
				$drive_by_location{$loc}->{"type"},
				$drive_by_location{$loc}->{"state"},
				defined $drive_by_location{$loc}->{"smart_alert"} ? $drive_by_location{$loc}->{"smart_alert"} : "-",
				defined $drive_by_location{$loc}->{"member_of_raid"} ? $drive_by_location{$loc}->{"member_of_raid"} : "-",
				defined $drive_by_location{$loc}->{"device"} && defined $disks{$drive_by_location{$loc}->{"device"}} ? grep ( /by-path\/pci/, @{$disks{$drive_by_location{$loc}->{"device"}}->{'device_aliases'}} ) : "-"
			);
		}
	} else {
		# TODO: change to print by-path device name
		if ( defined $drive_by_location{$options{'locations'}}->{'device'} ) {
			printf("%s\n", $drive_by_location{$options{'locations'}}->{'device'});
		} else {
			exit 1;
		}
	}

} elsif ( defined $options{'slots'} ) {
	if ( $options{'slots'} eq "" ) {
		# slot name ( the sZ of /cX/eY/sZ), device type, device state, device smart state (if avail), device name (sdX if avail), raid name (/cX/vY), long device name (by-path if avail)
		printf("%-5s %-3s %-13s %-4s %-11s %-5s %-5s %-9s %s\n","#Slot","No.","Location","Dev","Type","State","Smart","RAID","Device-by-path");
		foreach my $loc ( sort megaraid_slot_numerically keys %drive_by_location ) {
			printf("%-5s %-3s %-13s %-4s %-11s %-5s %-5s %-9s %s\n",
				defined $drive_by_location{$loc}->{"slot"} ? $drive_by_location{$loc}->{"slot"} : "-",
				defined $drive_by_location{$loc}->{"slot_number"} ? $drive_by_location{$loc}->{"slot_number"} : "-",
				$loc,
				defined $drive_by_location{$loc}->{"device"} ? $drive_by_location{$loc}->{"device"} : "-",
				$drive_by_location{$loc}->{"type"},
				$drive_by_location{$loc}->{"state"},
				defined $drive_by_location{$loc}->{"smart_alert"} ? $drive_by_location{$loc}->{"smart_alert"} : "-",
				defined $drive_by_location{$loc}->{"member_of_raid"} ? $drive_by_location{$loc}->{"member_of_raid"} : "-",
				defined $drive_by_location{$loc}->{"device"} && defined $disks{$drive_by_location{$loc}->{"device"}} ? grep ( /by-path\/pci/, @{$disks{$drive_by_location{$loc}->{"device"}}->{'device_aliases'}} ) : "-"
			);
		}
	} else {
		if ( defined $drive_by_slot{$options{'slots'}}->{'location'} && 
			defined $drive_by_location{$drive_by_slot{$options{'slots'}}->{'location'}}->{"device"} && 
			defined $disks{$drive_by_location{$drive_by_slot{$options{'slots'}}->{'location'}}->{'device'}} ) {
			my @dev=grep ( /by-path\/pci/, @{$disks{$drive_by_location{$drive_by_slot{$options{'slots'}}->{'location'}}->{'device'}}->{'device_aliases'}});
			print "@dev\n";

		} else {
			exit 1;
		}
	}
}
# The End.

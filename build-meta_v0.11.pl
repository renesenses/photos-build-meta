#!/usr/bin/perl -w

# WRITTEN TO CLEAN BAD DIRS DIMENSION

use File::Compare;
use File::Basename;
use File::Path;
use File::Spec;
use File::Copy;
use File::Find;

# use strict;

my $nb_read 			= 0;
my $nb_scans 			= 0;
my $nb_scans_in_error 	= 0;
my $nb_scans_mod 		= 0;
my $nb_total 			= 0;

my $dim_home;

my $target_file;
my $target_dir;

my $BACKUP_VOLUME 				= "/Volumes/BACKUP/";
my $BACKUP_DIR 					= "SAUVEGARDES/IMAGES";

my $ICLOUD_DIR					= "ICLOUD";
my $ERROR_DIR 					= "ERROR_META";

my $CSV_EXPORT 					= "/Users/LochNessIT/Desktop/export_csv";

# my $REL_PICTURES_STEP_1_DIR 	= "/TEST/SCANS";
# my $REL_PICTURES_STEP_2_DIR 	= "/MINOLTA/TEST";
my $REL_PICTURES_STEP_2_DIR 	= "/TEST_MINOLTA/META";
my $REL_PICTURES_STEP_3_DIR 	= "/MINOLTA/POST";
my $REL_PICTURES_STEP_4_DIR 	= "/MINOLTA/TEMP";

### SUB ###

# With $var instead

sub mount_volume {
	my $volume = $_[0];
	my $cmd = `mount -t smbfs //192.168.1.10/BACKUP $BACKUP_VOLUME`;
}

sub file_exists {
	my $vol = $_[0]; 
	if (-e($vol)) {
		return 1;
	}
	else {
		return 0;
	}
}

sub get_file_extension {
	my $fullname = $_[0];
	my ($file,$dir,$ext) = fileparse($fullname, qr/\.[^.]*/);
	if ($ext eq "") {
		return $ext;
	}
	else {
		return substr($ext,1);
	}
}

sub print_nb_scans {
	print "PRINTING SCANS_FILES and nb_scans \n";
	foreach my $file (sort keys %SCANS_FILES) {
		print "\t DIR \t [ ",$file," ] \n";
	}
}

sub print_SCANS_FILES {
	print "PRINTING SCANS_FILES \n";
	foreach my $file (keys %SCANS_FILES) {
		print "\t FILE \t [ ",$file,	"\t",$SCANS_FILES{$file}{dir_type},
									"\t",$SCANS_FILES{$file}{dir_year},
									"\t",$SCANS_FILES{$file}{dir_event},
						" ] \n";
	}
}

# Called by File::Find and do not backup hidden files

# scans_dir : SCANS
# image_dir : META

# HASH SCANS_FILES : {dir_name}, nb_scans

sub read_diapos {

	my $dir_type;
	my $dir_name;
#	my @file_error_array;
	my $file_name;
	my $dir_event;
	my $dir_year;
	my $nulldir;
	my $file_extension;
	my $file_sequence;
	my $file_version;
	my $error_status;
	
	my $file_name_id;
		
	if ( !($_ =~ /^\./) ) {
#		print "ENTRY : ",$File::Find::name,"\n";
		if ( -f $_ ) {
			$file_sequence =0;
			$file_version = 0;
#			print "FILE : ",$File::Find::name,"\n";
			$nb_read++;
			my @dirs = File::Spec->splitdir($File::Find::name);
#			print "DIRS : ",join("/",@dirs),"\n"; 
			
			$file_name 			= pop(@dirs);
			$file_extension 	= get_file_extension($file_name);
			$dir_event			= pop(@dirs);
			$dir_year			= pop(@dirs);
			$dir_type			= pop(@dirs);
		
		# REGEX NOT DESIGNED SO USING A SET OF NASTY IFs 	
		# MATCHING THE REGEX
		# TEMPLATE : /^([0-9]){4})_(A-STRING)_([0-9]){3})?_v([0-9]){3})$/
		
			if ( $file_name =~ /_([0-9]{3})((_v([0-9]){3})?)$/ ) {
				$error_status = 0;
				if ($1) { $file_sequence = $1+0 }; # chaine de 3 caractères forced in int
				if ($2) { $file_version = $2+0 }; # chaine de 3 caractères forced in int
			}	
			
		$dir_name = File::Spec->catdir($dir_year,$dir_event);

			
		my $rec;
			
			$rec->{dir_name} 			= $dir_name;
			
			$rec->{dir_event} 			= $dir_event;
			$rec->{dir_year} 			= $dir_year;
			$rec->{dir_type} 			= $dir_type;
			$rec->{file_extension} 		= $file_extension;
			$rec->{file_sequence} 		= $file_sequence;

			$rec->{file_version} 		= $file_version;
			$rec->{file_name} 			= $file_name;
			$rec->{error_status} 		= $error_status;
			$rec->{filename_id}			= $File::Find::name;

#			print "FILE_NAME : ",$rec->{file_name}, "\t |";
#			print "DIR_NAME : ",$rec->{dir_name}, "\t |";
#			print "DIR_EVENT : ",$rec->{dir_event}, "\t |";
#			print "DIR_YEAR : ",$rec->{dir_year}, "\t |";
#			print "DIR_TYPE : ",$rec->{dir_type}, "\t |";						
#			print "FILE_EXT : ",$rec->{file_extension},  "\t |";	
#			print "FILE_VERSION : ",$rec->{file_version}, "\t |";	
#			print "FILE_SEQUENCE : ",$rec->{file_sequence}, "\n" ;	
			
			$SCANS_FILES{ $rec->{filename_id} } = $rec;	
		}
	}
}


### MAIN ###

my $scans_dir;
my %SCANS_FILES;

print "Debug : START","\n";


if (! (-e $BACKUP_VOLUME) ) {
	my $res = `mkdir $BACKUP_VOLUME`;
	if ( -d $BACKUP_VOLUME ) {
		mount_volume($BACKUP_VOLUME);
	}
	else {
		print "Echec à la création de ",$BACKUP_VOLUME,"\n";	
	}
}	


my $ABS_PICTURES_STEP_2_DIR = File::Spec->catdir( $BACKUP_VOLUME, $BACKUP_DIR, $REL_PICTURES_STEP_2_DIR );	
my @ABS_PICTURES_STEP_2_DIR = File::Spec->splitdir( $ABS_PICTURES_STEP_2_DIR );

$dim_home = $#ABS_PICTURES_STEP_2_DIR;
print "DIM home : ",$dim_home,"\n";	
	
#	find(\&print_dir, $ABS_PICTURES_STEP_1_DIR );
	
#finddepth( \&check_diapos, $ABS_PICTURES_STEP_2_DIR );
#clean_diapos;
	
find( \&read_diapos, $ABS_PICTURES_STEP_2_DIR );
#print_nb_scans;	
	
	
print "Repository read : ",$ABS_PICTURES_STEP_2_DIR, "\n";
print "Nb read : ",$nb_read,"\n";
print "Nb scans : ",$nb_scans,"\n";
print "Nb scans in error : ",$nb_scans_in_error,"\n";
print "Nb scans moved : ",$nb_scans_mod,"\n";